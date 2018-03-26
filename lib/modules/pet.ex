defmodule Pet do
    use GameDef 

    # 升星所需要的item
    @raise_items %{1 => %{name: "pet_bless_card", blessing: 150}, 2 => %{name: "pet_pill", blessing: 10}}
    # 幻形激活 激活id: 101,所需item_id: 1001, count: 1
    @actived_items %{101 => %{item_id: 1001, count: 1}, 102 => %{item_id: 1002, count: 5}} #actived_id => %{item_id: 0, count: 0}
    # 幻形配置表，id和进阶所需要的bless
    @hx_list %{101 => %{level: 1, bless: 40}, 111 => %{level: 2, bless: 90}, 121 => %{level: 3, bless: 190} }
    # 灵丹items
    @soul_items %{201 => %{life: 800}, 202 => %{life: 4000, defence: 40}, 203 => %{defence: 40}}
    # 宠物升级所需经验
    # @exp %{1 => 10, 2 => 15, 3 => 25, 4 => 40, 5 => 60}
    # 吞噬的装备
    @swallow_equip %{301 => %{exp: 100}, 401 => %{exp: 1000}, 501 => %{exp: 1500}}

    GameDef.defconf view: "actors/pet", getter: :get

    def get(_), do: %{}
    
    # %{ pet_id: 1, blessing: 0, exp: 0, beast_soul: %{a_id => use_count, b_id => 0, c_id => 0}, actived: %{actived_id => blessing}, hh: hh_id}
    def prop(pet) do
        pet_prop = pet |> Map.get(:pet_id, 0) |> get() |> Map.get(:props, %{}) |> Map.to_list() 
        beast_prop = pet 
        |> Map.get(:beast_soul, %{}) 
        |> Enum.map(fn {k, v} -> 
            Map.get(@soul_items, k) |> Enum.map(fn {k, v1} -> {k, v1 * v} end) 
        end) 
        |> List.flatten()
        Enum.concat(pet_prop, beast_prop)
    end

    # 吞噬装备 equip is a map: %{id => count, id1 => count1, id2 => count2}
    def swallow(equip, {id, %{pet: %{exp: exp} = pet, bag: bag}}) do
        with true <- equip |> Map.to_list() |> Enum.map(fn {id, count} -> Inventory.enough?(bag, id, count) end) 
            |> Enum.all?(fn x -> true == x end)
        do
            cost = equip |> Map.to_list() |> Enum.map(fn {id, count} -> {:item, id, count} end)
            {cost_events, [new_bag, new_exp]} = equip 
            |> Map.to_list() 
            |> Enum.flat_map_reduce([bag, exp], fn({id, count}, [bag, exp]) ->              
                {_, poped, bag} = Inventory.pop_some(bag, id, count)
                events = (poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end))
                exp = exp + count * @swallow_equip[id][:exp]
                {events, [bag, exp]}
            end)
            new_pet = %{pet | exp: new_exp}
            swallow_events  = {{:pet, :swallow}, id, %{exp: new_exp}}
            context = %{action: {}, events: [swallow_events, cost_events], changed: %{bag: new_bag, pet: new_pet}}   
            {:resolve, context, Effect.from_cost(cost)}
        else
            _ -> :ok
        end
    end

    # 幻形激活
    def active(actived_id, {id, %{pet: %{actived: actived} = pet, bag: bag}}) do
        with %{item_id: need_id, count: need_count} = Map.get(@actived_items, actived_id, %{}),
            true <- Inventory.enough?(bag, need_id, need_count),
            false <- Map.has_key?(actived, actived_id)
        do
            cost = [{:item, need_id, need_count}]
            {_, poped, new_bag} = Inventory.pop_some(bag, need_id, need_count)
            new_actived = Map.put(actived, actived_id, 0)
            new_pet = %{pet | actived: new_actived}
            active_events = {{:pet, :active}, id, %{actived: new_actived}}
            cost_events = poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)
            context = %{action: {}, events: [active_events, cost_events], changed: %{bag: new_bag, pet: new_pet}}   
            {:resolve, context, Effect.from_cost(cost)}
        else
            _ -> :ok
        end
    end

    # 幻化
    def hh(new_hh_id, {id, %{pet: %{pet_id: pet_id, actived: actived, hh: hh_id} = pet}}) do
        if (new_hh_id == pet_id and new_hh_id != hh_id) or (Map.has_key?(actived, new_hh_id) and new_hh_id != hh_id) do
            events = [{{:pet, :hh}, id, %{hh: new_hh_id}}]
            changed = %{pet: %{pet | hh: new_hh_id}}
            {:notify, events, changed}
        else
            :ok
        end
    end

    # pet 升星 进阶
    def pet_advanced(eat_item_id, count, {id, %{pet: %{pet_id: _pet_id, blessing: blesssing, actived: actived} = pet, bag: bag}}) do
        with  true <- Inventory.enough?(bag, eat_item_id, count) do
            bless = @raise_items |> Map.get(eat_item_id, %{}) |> Map.get(:blessing, 0)
            now_bless = count * bless + blesssing
            new_pet_id = get_next_id(now_bless)
            new_pet = %{pet | pet_id: new_pet_id, blessing: now_bless}
            actived_id = div(new_pet_id, 10) * 10 + 1
            cost = [{:item, eat_item_id, count}]
            {_, poped, new_bag} = Inventory.pop_some(bag, eat_item_id, count)
            pet_events = {{:pet, :advanced}, id, %{pet: new_pet}} 
            cost_events = poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)
            if Map.has_key?(actived, actived_id) do
                context = %{action: {}, events: [pet_events, cost_events], changed: %{bag: new_bag, pet: new_pet}}
            else
                new_actived = Map.put(actived, actived_id, 0)
                new_pet = %{pet | pet_id: new_pet_id, blessing: now_bless, actived: new_actived}
                active_events = {{:pet, :active}, id, %{actived: new_actived}}
                context = %{action: {}, events: [pet_events, cost_events, active_events], changed: %{bag: new_bag, pet: new_pet}}
            end
            {:resolve, context, Effect.from_cost(cost)}
        else
            _ -> :ok
        end
    end

    # 幻形 进阶
    def hx_advanced(eat_item_id, count, hx_id, {id, %{ pet: %{actived: actived} = pet, bag: bag}} ) do
        with true <- Inventory.enough?(bag, eat_item_id, count) do
            blessing = pet[:actived][hx_id]
            bless = @raise_items |> Map.get(eat_item_id, %{}) |> Map.get(:blessing, 0)
            now_bless = count * bless + blessing
            new_hx_id = get_hx_id(now_bless)
            new_actived = actived |> Map.delete(hx_id) |> Map.merge(%{new_hx_id => now_bless})
            new_pet =  %{pet | actived: new_actived}
            cost = [{:item, eat_item_id, count}]
            {_, poped, new_bag} = Inventory.pop_some(bag, eat_item_id, count)
            actived_events = {{:pet, :hx_advanced}, id, %{actived: new_actived}}
            cost_events = poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)
            context = %{action: {}, events: [actived_events, cost_events], changed: %{bag: new_bag, pet: new_pet}}
            {:resolve, context, Effect.from_cost(cost)}
        else
            _ -> :ok
        end
    end

    # 灵丹
    def beast_soul(item_id, count, {id, %{pet: %{beast_soul: beast_soul} = pet, bag: bag}}) do
        with true <- Inventory.enough?(bag, item_id, count) do
            if Map.has_key?(beast_soul, item_id) do
                new_beat_soul = %{beast_soul | item_id => beast_soul[item_id] + count}
            else
                new_beat_soul = beast_soul |> Map.merge(%{item_id => count})
            end
            new_pet =  %{pet | beast_soul: new_beat_soul}
            cost = [{:item, item_id, count}]
            {_, poped, new_bag} = Inventory.pop_some(bag, item_id, count)
            cost_events = poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)
            soul_events = {{:pet, :beast_soul}, id, %{beast_soul: new_beat_soul}}
            context = %{action: {}, events: [soul_events, cost_events], changed: %{bag: new_bag, pet: new_pet}}
            {:resolve, context, Effect.from_cost(cost)}
        else
            _ -> :ok
        end
    end

    def get_next_id(blessing, id \\ 0) do
        bless = get(id + 1) |> Map.get(:bless, -1)
        if bless != -1 and blessing - bless > 0 do
            get_next_id(blessing - bless, id + 1)
        else
            id
        end
    end

    def get_hx_id(blessing, id \\ 101) do
        bless = Map.get(@hx_list, id) |> Map.get(:bless, -1)
        if bless != -1 and blessing - bless > 0 do
            get_next_id(blessing - bless, id + 10)
        else
            id
        end
    end

end