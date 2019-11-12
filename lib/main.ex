defmodule Main do
  use Application
  import Supervisor.Spec
  require Logger

  @app :ssss_server

  def start(_type, _args) do
    # avatars, systems, services, scenes (zone & instance)
    # main这个监控树的子进程
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
    []
  end

  defp opts(name), do: [strategy: :one_for_one, name: name]

  defp bootstrap do
    # 打开存放角色资料的文件（通过:dets）
    Repo.init()
    # 打开存放物品资料的文件（通过:dets）
    Item.init()

    # 从/config/config.exs中获取
    port = Application.get_env(@app, :port, 3256)
    # 使用:ranch来监听端口，用Session模块来处理
    {:ok, _} = :ranch.start_listener(:tcp_gate, 10, :ranch_tcp, [port: port], Session, [])

    :ok
  end

  def prep_stop(state) do
    # def save(avatar_id, data) do
    #   Repo.save(:character, avatar_id, data)
    # end
    Logger.info("mian>prep_stop> state is #{inspect(state, pretty: true)}")
    Repo.close()
    state
  end
end
