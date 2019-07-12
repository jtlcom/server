defmodule Account do
  def auth(account, _claim \\ nil, _proof \\ nil) do
    {:ok, :erlang.phash2(account)}
  end
end
