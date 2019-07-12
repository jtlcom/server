defmodule Slots do
  def bind(slots, key, item) do
    slots |> Map.get_and_update(key, fn curr -> {curr, item} end)
  end

  defdelegate get(slots, key), to: Map

  defdelegate unbind(slots, key), to: Map, as: :pop
end
