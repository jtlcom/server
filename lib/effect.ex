defmodule Effect do

  def from_cost(cost) when is_tuple(cost) do
    List.wrap(cost) |> from_cost
  end

  def from_cost(cost) do
    cost |> Enum.map(fn
      {:item, id, count} -> {:lost, {:item, id}, count}
      {{:bag, index}, count} -> {:lost, {:bag, index}, count}
      {point, amount} -> {:lost, point, amount}
    end)
  end

  def from_rewards(rewards) when is_tuple(rewards) do
    List.wrap(rewards) |> from_rewards
  end

  def from_rewards(rewards) do
    rewards |> Enum.map(fn
      {:item, id, count} -> {:gain, {:item, id}, count}
      {point, amount} -> {:gain, point, amount}
    end)
  end

  def from_cost_rewards(cost, rewards) do
    Enum.concat from_cost(cost), from_rewards(rewards)
  end

  def resolve({:gain, :item, item}, {id, _context, %{bag: bag}}) do
    {cell, bag} = bag |> Inventory.store(item)
    event = {{:bag, :gain}, id, %{cell => item}}

    {event, %{bag: bag}}
  end

  def resolve({:gain, {:item, item_id}, count}, {id, _context, %{bag: bag}}) do
    {cells, bag} = bag |> Inventory.stack(item_id, count)

    {{{:bag, :gain}, id, Map.new(cells)}, %{bag: bag}}
  end

  def resolve({:gain, {mod, prop}, amount}, {id, _context, data}) do
    with group when not is_nil(group) <- Map.get(data, mod),
      original when not is_nil(original) <- Map.get(group, prop),
      current = original + amount
    do
      {{:prop_changed, id, %{mod => %{prop => current}}}, %{mod => %{group | prop => current}}}
    else
      _ -> {[], %{}}
    end
  end

  def resolve({:gain, prop, amount}, {id, _context, %{currencies: currencies, points: points}}) do
    if Map.has_key?(currencies, prop) do
      current = Map.get(currencies, prop) + amount
      {{:prop_changed, id, %{prop => current}}, %{currencies: %{currencies | prop => current}}}
    else
      if Map.has_key?(points, prop) do
        current = Map.get(points, prop) + amount
        {{:prop_changed, id, %{prop => current}}, %{points: %{points | prop => current}}}
      end
    end
  end

  def resolve({:lost, {:bag, index}, count}, {id, _context, %{bag: bag}}) do
    {lost, bag} = Inventory.pop_some_at(bag, index, count)
    {{{:bag, :lost}, id, %{index => lost}}, %{bag: bag}}
  end

  def resolve({:lost, {:item, item_id}, count}, {id, _context, %{bag: bag}}) do
    {^count, poped, bag} = Inventory.pop_some(bag, item_id, count)
    {{{:bag, :lost}, id, Map.new(poped)}, %{bag: bag}}
  end

  def resolve({:lost, {mod, prop}, amount}, {id, _context, data}) do
    with group when not is_nil(group) <- Map.get(data, mod),
      original when not is_nil(original) <- Map.get(group, prop),
      current = original - amount
    do
      {{:prop_changed, id, %{mod => %{prop => current}}}, %{mod => %{group | prop => current}}}
    else
      _ -> {[], %{}}
    end
  end

  def resolve({:lost, prop, amount}, {id, _context, %{currencies: currencies, points: points}}) do
    if Map.has_key?(currencies, prop) do
      current = Map.get(currencies, prop) - amount
      {{:prop_changed, id, %{prop => current}}, %{currencies: %{currencies | prop => current}}}
    else
      if Map.has_key?(points, prop) do
        current = Map.get(points, prop) - amount
        {{:prop_changed, id, %{prop => current}}, %{points: %{points | prop => current}}}
      end
    end
  end

  def resolve(effect, {_id, _context, _data}) do
    IO.puts "unknown effect #{inspect effect}"

    {[], %{}}
  end
end
