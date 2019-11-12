defmodule Inventory do
  require Logger
  # 把这个item存入这个bag
  def store(bag, item) do
    # 找到bag可用的index，新的index，和index值为nil表示可用
    index = available_cell(bag)
    {index, bag |> Map.put(index, item)}
  end

  # 把这个item存入这个bag
  def store(bag, item, bagMaxSize) do
    # 找到bag可用的index，新的index，和index值为nil表示可用
    index = available_cell(bag, bagMaxSize)
    {index, bag |> Map.put(index, item)}
  end

  def store_at(bag, index, item) do
    {index, bag |> Map.put(index, item)}
  end

  # 把东西存入bag
  def stack(bag, item_id, count) do
    # find去背包中查找item_id这一项 找到了返回{index, item}，没找到返回nil
    case Logical.stackable?(item_id) and find(bag, &match?(%{id: ^item_id}, &1)) do
      {index, item} ->
        Logger.debug("case 1")
        item = item |> Logical.stack(count)
        Logger.debug("item: #{inspect(item, pretty: true)}")
        Logger.debug("index: #{inspect(index, pretty: true)}")
        {^index, bag} = bag |> store_at(index, item)
        {[{index, item}], bag}

      nil ->
        Logger.debug("case nil")
        # 创建bag中的一个物品项
        item = Logical.new(item_id, count)
        # 把这个item存入这个bag 返回存入item的index，新的bag
        {index, bag} = bag |> store(item)
        {[{index, item}], bag}

      false ->
        Logger.debug("case false")

        Stream.repeatedly(fn -> Logical.new(item_id) end)
        |> Enum.take(count)
        |> Enum.map_reduce(bag, fn item, bag ->
          {cell, bag} = bag |> Inventory.store(item)
          {{cell, item}, bag}
        end)
    end
  end

  # 把东西存入bag
  def stack(bag, item_id, count, bagMaxSize) do
    # find去背包中查找item_id这一项 找到了返回{index, item}，没找到返回nil
    case Logical.stackable?(item_id) and find(bag, &match?(%{id: ^item_id}, &1)) do
      {index, item} ->
        Logger.debug("case 1")
        item = item |> Logical.stack(count)
        Logger.debug("item: #{inspect(item, pretty: true)}")
        Logger.debug("index: #{inspect(index, pretty: true)}")
        {^index, bag} = bag |> store_at(index, item)
        {[{index, item}], bag}

      nil ->
        Logger.debug("case nil")
        # 创建bag中的一个物品项
        item = Logical.new(item_id, count)
        # 把这个item存入这个bag 返回存入item的index，新的bag
        {index, bag} = bag |> store(item, bagMaxSize)
        {[{index, item}], bag}

      false ->
        Logger.debug("case false")

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

  def getItem(bag, index) do
    Map.get(bag, index)
  end

  def count(bag, item_id) do
    bag
    |> Enum.reduce(0, fn
      {_, %{id: ^item_id} = item}, sum -> sum + stock(item)
      _, sum -> sum
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
    bag
    |> Map.get_and_update(index, fn item ->
      stock = stock(item)
      changed = if stock > count, do: %{item | count: stock - count}, else: nil
      {min(stock, count), changed}
    end)
  end

  def pop_some(bag, item_id, count) do
    bag
    |> Enum.reduce_while({0, [], bag}, fn {index, item}, {sum, poped, bag} ->
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

  # 找到bag可用的index，新的index，和index值为nil表示可用
  def available_cell(bag) do
    0..map_size(bag) |> Enum.find(fn index -> available?(bag, index) end)
  end

  # 找到bag可用的index，新的index，和index值为nil表示可用
  def available_cell(bag, bagMaxSize) do
    0..(bagMaxSize - 1) |> Enum.find(fn index -> available?(bag, index) end)
  end

  defp stock(nil), do: 0

  defp stock(item) do
    item |> Map.get(:count, 1)
  end

  # bag没有index 的key，或bag的index的值是nil ，这两种情况表示bag的index可用 返回true
  defp available?(bag, index) do
    not Map.has_key?(bag, index) or is_nil(Map.get(bag, index))
  end

  def bag_can_store?(bag, bagMaxSize, item_id) do
    # 仓库的背包未满，一定可以再放物品
    case bagMaxSize > map_size(bag) do
      true ->
        true

      false ->
        bag |> Map.to_list() |> Enum.any?(fn {_index, %{id: id}} -> match?(id, item_id) end)
    end
  end

  def warehouse_can_store?(%{max: max_cells, bag: bag}, item_id) do
    # 仓库的背包未满，一定可以再放物品
    case max_cells > map_size(bag) do
      true ->
        true

      false ->
        bag |> Map.to_list() |> Enum.any?(fn {_index, %{id: id}} -> match?(id, item_id) end)
    end
  end
end
