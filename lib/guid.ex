defmodule Guid do
  import Bitwise
  @server_id Application.get_env(:ssss_server, :server_id)

  def name(name) when is_atom(name) do
    name
  end

  def name(guid) do
    {:via, Registry, {Registry.ByGuid, guid}}
  end

  def new(:avatar, id) do
    @server_id <<< 24 ||| id
  end

  def describe(guid) when (guid >>> 0) === 0x0000 do
    %{catgory: :avatar, id: guid &&& 0xFFFFFF, server_id: (guid >>> 24) &&& 0xFFFF}
  end

  def online?(guid) do
    match?([_], Registry.lookup(Registry.ByGuid, guid))
  end
end

defmodule Guid.Supervisor do
  use Supervisor

  @name Guid
  @worker_name GuidServer

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init(_) do
    children = [
      {Registry, keys: :unique, name: Registry.ByGuid, listeners: [@worker_name]},
      {Guid.Server, name: @worker_name}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Guid.Server do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init() do
    {:ok, %{}}
  end

  def handle_info({:register, Registry.ByGuid, _guid, _pid, _}, state) do
    {:noreply, state}
  end

  def handle_info({:unregister, Registry.ByGuid, _guid, _pid}, state) do
    {:noreply, state}
  end
end
