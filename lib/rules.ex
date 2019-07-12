defmodule Rules do
  require Logger

  def apply_rule(changed, _data) when is_map(changed) do
    {nil, changed}
  end

  def apply_rule(event, _data) when is_tuple(event) do
    {nil, %{}}
  end
end
