defmodule Logical do
  defdelegate get(id), to: Item
  defdelegate get_object(id), to: Item

  def new(id) do
    %{id: id}
  end

  def new(id, count) do
    %{id: id, count: count}
  end

  def stackable?(id) do  #去Item里面取stack意义？
    get(id) |> Map.get(:stack, 0) > 0
  end

  def stack(item, amount) do
    item |> Map.update(:count, amount + 1, &(&1 + amount)) #更新物品数量
  end

  def require(id) do   #取出item_id物品的require属性
    case get(id) do
      %{require: requirements} -> requirements
      _ -> nil
    end
  end

  def use(id) do  #获取使用该物品的规则
    case get(id) do
      %{actions: actions} when map_size(actions) == 1 -> actions |> Enum.at(0)
      _ -> nil
    end
  end

  def sell(id) do
    action(id, :sell)
  end

  def sell_object(id) do
    action_object(id, :sell)
  end

  def buy(id) do
    action_object(id, :buy)
  end

  def swallow_equip( id ) do 
    action(id, :sell)
  end

  def action(id, action) do
    case get(id) do
      %{^action => rule} -> rule
      %{actions: actions} -> actions |> Map.get(action)
      _ -> nil
    end
  end

  def action_object(id, action) do
    case get_object(id) do
      %{^action => rule} -> rule
      %{actions: actions} -> actions |> Map.get(action)
      _ -> nil
    end
  end
end
