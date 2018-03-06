defmodule Main do
  use Application
  import Supervisor.Spec
  require Logger

  @app :ssss_server

  def start(_type, _args) do
    # avatars, systems, services, scenes (zone & instance)

    children = [
      Avatar.Supervisor,
      # Scene.Supervisor,
      supervisor(Supervisor, [services(), opts(Services)], id: Services),
      supervisor(Supervisor, [systems(), opts(Systems)], id: Systems)
    ]

    Supervisor.start_link(children, opts(Realm))
  end

  def start_phase(:init, _type, _) do
    bootstrap()
  end

  defp services do
    [
      Guid.Supervisor,
      # worker(Redix, [Application.get_env(@app, :redis_url), [name: :redix]]),
      Scheduler
    ]
  end

  defp systems do
    [

    ]
  end

  defp opts(name), do: [strategy: :one_for_one, name: name]

  defp bootstrap do
    Repo.init
    Item.init

    port = Application.get_env(@app, :port, 3256)
    {:ok, _} = :ranch.start_listener(:tcp_gate, 10, :ranch_tcp, [port: port], Session, [])

    :ok
  end
end
