defmodule Inventory do
  def store(bag, item) do
    index = available_cell(bag)
    {index, bag |> Map.put(index, item)}
  end

  def store_at(bag, index, item) do
    {index, bag |> Map.put(index, item)}
  end

  def stack(bag, item_id, count) do
    case Logical.stackable?(item_id) and find(bag, &(match?(%{id: ^item_id}, &1))) do
      {index, item} ->
        item = item |> Logical.stack(count)
        {^index, bag} = bag |> store_at(index, item)
        {[{index, item}], bag}
      nil ->
        item = Logical.new(item_id, count)
        {index, bag} = bag |> store(item)
        {[{index, item}], bag}
      false ->
        Stream.repeatedly(fn -> Logical.new(item_id) end)
        |> Enum.take(count)
        |> Enum.map_reduce(bag, fn item, bag ->
            {cell, bag} = bag |> Inventory.store(item)
            {{cell, item}, bag}
          end)
    end
  end

  def get(bag, index) do
    item = Map.get(bag, index)
    {item, stock(item)}
  end

  def count(bag, item_id) do
    bag |> Enum.reduce(0, fn
      {_, %{id: ^item_id} = item}, sum -> sum + stock(item)
      _ , sum -> sum
    end)
  end

  # TODO: optimzie
  def enough?(bag, item_id, count) do
    count(bag, item_id) >= count
  end

  def find(bag, fun) do
    bag |> Enum.find(fn {_, item} -> fun.(item) end)
  end

  defdelegate pop_at(bag, index), to: Map, as: :pop

  def pop_some_at(bag, index, count) do
    bag |> Map.get_and_update(index, fn item ->
      stock = stock(item)
      changed = if stock > count, do: %{item | count: stock - count}, else: nil
      {min(stock, count), changed}
    end)
  end

  def pop_some(bag, item_id, count) do
    bag |> Enum.reduce_while({0, [], bag}, fn {index, item}, {sum, poped, bag} ->
      stock = stock(item)

      cond do
        item == nil or item[:id] != item_id ->
          {:cont, {sum, poped, bag}}
        sum + stock == count ->
          {:halt, {count, [{index, stock} | poped], bag |> Map.delete(index)}}
        sum + stock > count ->
          {some, bag} = bag |> pop_some_at(index, count - sum)
          {:halt, {count, [{index, some} | poped], bag}}
        true ->
          {:cont, {sum + stock, [{index, stock} | poped], bag |> Map.delete(index)}}
      end
    end)
  end

  def swap(bag, a, b) do
    %{^a => ia, ^b => ib} = bag
    bag |> Map.put(a, ib) |> Map.put(b, ia)
  end

  def available_cell(bag) do
    0..map_size(bag) |> Enum.find(fn index -> available?(bag, index) end)
  end

  defp stock(nil), do: 0

  defp stock(item) do
    item |> Map.get(:count, 1)
  end

  defp available?(bag, index) do
    not Map.has_key?(bag, index) or is_nil(Map.get(bag, index))
  end
end
