defmodule Action do
  # 判断requirements （需要的条件） ，data是否满足，requirement可以是bag的东西，玩家等级（level），vip等级或其他属性
  def match?(nil, _data), do: true

  def match?(requirements, data) when is_list(requirements) or is_map(requirements) do
    Enum.all?(requirements, &Action.match?(&1, data))
  end

  def match?({{:bag, index}, count}, %{bag: bag}) do
    {_, stock} = Inventory.get(bag, index)
    stock >= count
  end

  def match?({:item, id, count}, %{bag: bag}) do
    Inventory.enough?(bag, id, count)
  end

  def match?({:level, min_level}, %{level: level}) do
    level >= min_level
  end

  def match?({:vip, min_level}, %{vip: %{level: vip_level}}) do
    vip_level >= min_level
  end

  def match?({{mod, prop}, amount}, data) do
    Map.has_key?(data, mod) and get_in(data, [mod, prop]) >= amount
  end

  def match?({prop, amount}, %{currencies: currencies, points: points}) do
    (Map.has_key?(currencies, prop) and Map.get(currencies, prop, 0) >= amount) or
      (Map.has_key?(points, prop) and Map.get(points, prop, 0) >= amount)
  end
end
