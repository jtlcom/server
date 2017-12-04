defmodule Router do
  def cast(guid, request) do
    GenServer.cast(Guid.name(guid), request)
  end

  def call(guid, request) do
    GenServer.call(Guid.name(guid), request)
  end

  def route(guid, request), do: cast(guid, request)

  def query(guid, id, path), do: call(guid, {:query, id, path})

  def notify(guid, event), do: cast(guid, {:notify, event})
end
