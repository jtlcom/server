defmodule Dressup do
  use GameDef

  @actived_items %{802 => %{item_id: 802, count: 1}, 810 => %{item_id: 810, count: 2}}
  @raise_items %{802 => %{item_id: 802, count: 1}, 810 => %{item_id: 810, count: 2}}
  @undress_id -1

  # GameDef.defconf view: "actors/dress", getter: :get

  def get(_), do: %{}

  def props() do
  end

  # 激活
  def active(type, active_id, {id, %{bag: bag} = data}) do
    dress = Map.get(data, type, %{})
    actived = Map.get(dress, :actived, %{})

    with false <- Map.has_key?(actived, active_id),
         %{item_id: need_id, count: need_count} = Map.get(@actived_items, active_id, %{}),
         true <- Inventory.enough?(bag, need_id, need_count) do
      cost = [{:item, need_id, need_count}]
      {_, poped, new_bag} = Inventory.pop_some(bag, need_id, need_count)
      new_actived = Map.put(actived, active_id, 0)
      new_dress = %{dress | actived: new_actived}
      active_events = {{type, :active}, id, %{actived: new_actived}}

      cost_events =
        poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)

      context = %{
        action: {},
        events: [active_events, cost_events],
        changed: %{bag: new_bag, dress: new_dress}
      }

      {:resolve, context, Effect.from_cost(cost)}
    else
      _ -> :ok
    end
  end

  # 升星
  def raisestar(type, raise_id, {id, %{bag: bag} = data}) do
    dress = Map.get(data, type, %{})
    actived = Map.get(dress, :actived, %{})

    with true <- Map.has_key?(actived, raise_id),
         %{item_id: need_id, count: need_count} = Map.get(@raise_items, raise_id, %{}),
         true <- Inventory.enough?(bag, need_id, need_count) do
      cost = [{:item, need_id, need_count}]
      {_, poped, new_bag} = Inventory.pop_some(bag, need_id, need_count)
      new_actived = %{actived | raise_id => Map.get(actived, raise_id) + 1}
      new_dress = %{dress | actived: new_actived}
      active_events = {{type, :active}, id, %{actived: new_actived}}

      cost_events =
        poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)

      context = %{
        action: {},
        events: [active_events, cost_events],
        changed: %{bag: new_bag, dress: new_dress}
      }

      {:resolve, context, Effect.from_cost(cost)}
    else
      _ -> :ok
    end
  end

  # 穿戴
  def dress(type, dress_id, {id, data}) do
    dress = Map.get(data, type, %{})
    actived = Map.get(dress, :actived, %{})

    with true <- Map.has_key?(actived, dress_id) do
      events = [{{type, :dress}, id, %{dress: dress_id}}]
      changed = Map.put(dress, :dress, dress_id)
      {:notify, events, changed}
    else
      _ -> :ok
    end
  end

  # 卸下
  def undress(type, undress_id, {id, data}) do
    dress = Map.get(data, type, %{})

    with true <- undress_id == Map.get(dress, :dress) do
      events = [{{type, :dress}, id, %{dress: @undress_id}}]
      changed = Map.put(dress, :dress, @undress_id)
      {:notify, events, changed}
    else
      _ -> :ok
    end
  end

  # 分解
  def breakup(type, breakup_id, count, {id, %{bag: bag} = data}) do
    dress = Map.get(data, type, %{})

    with true <- Inventory.enough?(bag, breakup_id, count) do
      cur_exp = Map.get(dress, :exp, 0) + count * 180
      cost = [{:item, breakup_id, count}]
      {_, poped, new_bag} = Inventory.pop_some(bag, breakup_id, count)
      new_dress = Map.put(dress, :exp, cur_exp)
      breakup_events = {{type, :breakup}, id, %{dress: new_dress}}

      cost_events =
        poped |> Enum.map(fn {index, count} -> {{:bag, :lost}, id, %{index => count}} end)

      context = %{
        action: {},
        events: [breakup_events, cost_events],
        changed: %{bag: new_bag, dress: new_dress}
      }

      {:resolve, context, Effect.from_cost(cost)}
    else
      _ -> :ok
    end
  end

  # 提升
  def essence(type, essence_id, {id, data}) do
    dress = Map.get(data, type, %{})
    actived = Map.get(dress, :actived, %{})

    with true <- Map.has_key?(actived, essence_id),
         true <- Map.get(dress, :exp, 0) >= 180 do
      cur_exp = Map.get(dress, :exp) - 180
      new_actived = %{actived | essence_id => Map.get(actived, essence_id) + 1}
      new_dress = %{dress | actived: new_actived, exp: cur_exp}
      essence_events = [{{type, :breakup}, id, %{dress: new_dress}}]
      {:notify, essence_events, new_dress}
    else
      _ -> :ok
    end
  end
end
