defmodule Logical do
  defdelegate get(id), to: Item

  def new(id) do
    %{id: id}
  end

  def new(id, count) do
    %{id: id, count: count}
  end

  def stackable?(id) do
    get(id) |> Map.get(:stack, 0) > 0
  end

  def stack(item, amount) do
    item |> Map.update(:count, amount + 1, &(&1 + amount))
  end

  def require(id) do
    case get(id) do
      %{require: requirements} -> requirements
      _ -> nil
    end
  end

  def use(id) do
    case get(id) do
      %{actions: actions} when map_size(actions) == 1 -> actions |> Enum.at(0)
      _ -> nil
    end
  end

  def sell(id) do
    action(id, :sell)
  end

  def action(id, action) do
    case get(id) do
      %{^action => rule} -> rule
      %{actions: actions} -> actions |> Map.get(action)
      _ -> nil
    end
  end
end
