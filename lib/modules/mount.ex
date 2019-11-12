defmodule Mount do
  use GameDef

  # 升星所需要的item
  @raise_items %{
    1 => %{name: "mount_bless_card", blessing: 150},
    2 => %{name: "mount_pill", blessing: 10}
  }
  # 幻形激活 激活id: 101,所需item_id: 1001, count: 1
  # actived_id => %{item_id: 0, count: 0}
  @actived_items %{101 => %{item_id: 1001, count: 1}, 102 => %{item_id: 1002, count: 5}}
  # 幻形配置表，id和进阶所需要的bless
  @hx_list %{
    101 => %{level: 1, bless: 40},
    111 => %{level: 2, bless: 90},
    121 => %{level: 3, bless: 190}
  }
  # 兽魂items
  @soul_items %{201 => %{life: 800}, 202 => %{life: 4000, defence: 40}, 203 => %{defence: 40}}

  # GameDef.defconf view: "actors/mount", getter: :get

  def get(_), do: %{}

  # %{ mount_id: 0, blessing: 0, beast_soul: %{a_id => use_count, b_id => 0, c_id => 0}, actived: %{actived_id => blessing}, hh: hh_id}
  def prop(mount) do
    mount_prop = mount |> Map.get(:mount_id, 0) |> get() |> Map.get(:props, %{}) |> Map.to_list()

    beast_prop =
      mount
      |> Map.get(:beast_soul, %{})
      |> Enum.map(fn {k, v} ->
        Map.get(@soul_items, k) |> Enum.map(fn {k, v1} -> {k, v1 * v} end)
      end)
      |> List.flatten()

    Enum.concat(mount_prop, beast_prop)
  end

  # 幻形激活
  def active(actived_id, {id, %{mount: %{actived: actived} = mount, bag: bag}}) do
    with %{item_id: need_id, count: need_count} = Map.get(@actived_items, actived_id, %{}),
         true <- Inventory.enough?(bag, need_id, need_count),
         false <- Map.has_key?(actived, actived_id) do
      cost = [{:item, need_id, need_count}]
      {_, poped, new_bag} = Inventory.pop_some(bag, need_id, need_count)
      new_actived = Map.put(actived, actived_id, 0)
      new_mount = %{mount | actived: new_actived}
      active_events = {{:mount, :active}, id, %{actived: new_actived}}

      cost_events =
        poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)

      context = %{
        action: {},
        events: [active_events, cost_events],
        changed: %{bag: new_bag, mount: new_mount}
      }

      {:resolve, context, Effect.from_cost(cost)}
    else
      _ -> :ok
    end
  end

  # 幻化
  def hh(new_hh_id, {id, %{mount: %{mount_id: mount_id, actived: actived, hh: hh_id} = mount}}) do
    if (new_hh_id == mount_id and new_hh_id != hh_id) or
         (Map.has_key?(actived, new_hh_id) and new_hh_id != hh_id) do
      events = [{{:mount, :hh}, id, %{hh: new_hh_id}}]
      changed = %{mount: %{mount | hh: new_hh_id}}
      {:notify, events, changed}
    else
      :ok
    end
  end

  # mount 升星 进阶
  def mount_advanced(
        eat_item_id,
        count,
        {id,
         %{mount: %{mount_id: mount_id, blessing: blesssing, actived: actived} = mount, bag: bag}}
      ) do
    with true <- Inventory.enough?(bag, eat_item_id, count) do
      bless = @raise_items |> Map.get(eat_item_id, %{}) |> Map.get(:blessing, 0)
      now_bless = count * bless + blesssing
      new_mount_id = get_next_id(now_bless)
      new_mount = %{mount | mount_id: new_mount_id, blessing: now_bless}
      actived_id = div(new_mount_id, 10) * 10 + 1
      cost = [{:item, eat_item_id, count}]
      {_, poped, new_bag} = Inventory.pop_some(bag, eat_item_id, count)
      mount_events = {{:mount, :advanced}, id, %{mount: new_mount}}

      cost_events =
        poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)

      context =
        if Map.has_key?(actived, actived_id) do
          %{
            action: {},
            events: [mount_events, cost_events],
            changed: %{bag: new_bag, mount: new_mount}
          }
        else
          new_actived = Map.put(actived, actived_id, 0)
          new_mount = %{mount | mount_id: new_mount_id, blessing: now_bless, actived: new_actived}
          active_events = {{:mount, :active}, id, %{actived: new_actived}}

          %{
            action: {},
            events: [mount_events, cost_events, active_events],
            changed: %{bag: new_bag, mount: new_mount}
          }
        end

      {:resolve, context, Effect.from_cost(cost)}
    else
      _ -> :ok
    end
  end

  # 幻形 进阶
  def hx_advanced(
        eat_item_id,
        count,
        hx_id,
        {id, %{mount: %{actived: actived} = mount, bag: bag}}
      ) do
    with true <- Inventory.enough?(bag, eat_item_id, count) do
      blessing = mount[:actived][hx_id]
      bless = @raise_items |> Map.get(eat_item_id, %{}) |> Map.get(:blessing, 0)
      now_bless = count * bless + blessing
      new_hx_id = get_hx_id(now_bless)
      new_actived = actived |> Map.delete(hx_id) |> Map.merge(%{new_hx_id => now_bless})
      new_mount = %{mount | actived: new_actived}
      cost = [{:item, eat_item_id, count}]
      {_, poped, new_bag} = Inventory.pop_some(bag, eat_item_id, count)
      actived_events = {{:mount, :hx_advanced}, id, %{actived: new_actived}}

      cost_events =
        poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)

      context = %{
        action: {},
        events: [actived_events, cost_events],
        changed: %{bag: new_bag, mount: new_mount}
      }

      {:resolve, context, Effect.from_cost(cost)}
    else
      _ -> :ok
    end
  end

  # 兽魂
  def beast_soul(item_id, count, {id, %{mount: %{beast_soul: beast_soul} = mount, bag: bag}}) do
    with true <- Inventory.enough?(bag, item_id, count) do
      new_beat_soul =
        if Map.has_key?(beast_soul, item_id) do
          %{beast_soul | item_id => beast_soul[item_id] + count}
        else
          beast_soul |> Map.merge(%{item_id => count})
        end

      new_mount = %{mount | beast_soul: new_beat_soul}
      cost = [{:item, item_id, count}]
      {_, poped, new_bag} = Inventory.pop_some(bag, item_id, count)

      cost_events =
        poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)

      soul_events = {{:mount, :beast_soul}, id, %{beast_soul: new_beat_soul}}

      context = %{
        action: {},
        events: [soul_events, cost_events],
        changed: %{bag: new_bag, mount: new_mount}
      }

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
