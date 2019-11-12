defmodule Avatar.Supervisor do
  use Supervisor
  @name Avatars
  require Logger

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def start_child(args, opts \\ []) do
    Logger.debug("Avatar.Supervisor -> start_child(args, opts \\ []) do")
    Supervisor.start_child(@name, [args, opts])
  end

  def init(_) do
    Supervisor.init([Avatar], strategy: :simple_one_for_one)
  end
end

defmodule Avatar do
  use GenServer, restart: :temporary
  @vsn 2

  require Logger

  @spec start_link(any(), any(), [
          {:debug, [:log | :statistics | :trace | {any(), any()}]}
          | {:hibernate_after, :infinity | non_neg_integer()}
          | {:name, atom() | {:global, any()} | {:via, atom(), any()}}
          | {:spawn_opt,
             :link
             | :monitor
             | {:fullsweep_after, non_neg_integer()}
             | {:min_bin_vheap_size, non_neg_integer()}
             | {:min_heap_size, non_neg_integer()}
             | {:priority, :high | :low | :normal}}
          | {:timeout, :infinity | non_neg_integer()}
        ]) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_, args, opts \\ []) do
    # Logger.debug "Avatar -> start_child(args, opts \\ []) do"
    GenServer.start_link(__MODULE__, args, opts)
  end

  # session may be an AI controller, or a client connection
  # TODO: design another mechanism to support restart notification to session/ai/observer
  def init({id, session}) do
    # Logger.debug "Avatar ->  init({id, session}) do"
    GenServer.cast(session, {:ack, self()})

    data = Character.load(id, @vsn)
    Logger.debug("Avatar ->  init({id, session})  return")
    # avatar_id  session_pid,date_character
    {:ok, {id, session, data}}
  end

  ####
  # def cast() do
  #   GenServer.call(__MODULE__,{:login,[]})
  # end
  ####
  def handle_cast({:login, _}, {id, session, %{pos: pos} = data}) do
    Logger.debug("avatar login")
    # send login response, with map info (id, x, y) for client to preload
    GenServer.cast(session, {:reply, {:login, [id, pos.map, pos.x, pos.y]}})

    # send avatar properties
    GenServer.cast(session, {:reply, {:info, client_info({id, data})}})

    # update data
    data = process_login({id, data})
    {:noreply, {id, session, data}}
  end

  def handle_cast({:logout, _}, {id, _session, data} = state) do
    Character.save(id, data)

    {:stop, :normal, state}
  end

  def handle_cast({{module, action}, args}, {id, _, data} = state) do
    # Logger.debug "avatar -> handle_cast({{module, action}, args}, {id, _, data} = state)"
    # TODO: pass module sub state when dispatching action
    #! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    dispatch(module, action, List.wrap(args) ++ [{id, data}])
    |> handle_result(state)
  end

  def handle_cast({skill, args}, state) do
    handle_cast({{:skill, skill}, args}, state)
  end

  defp dispatch(module, action, args) do
    require Utils

    # Logger.debug "dispatch"
    # 将字符串转为tuple,即对应成相应的模块
    mod = ("Elixir." <> (module |> Atom.to_string() |> Macro.camelize())) |> Utils.to_atom()
    func = action |> Atom.to_string() |> Macro.underscore() |> Utils.to_atom()

    Utils.ensure_module(mod)

    if function_exported?(mod, func, length(args)) do
      try do
        # Logger.debug "apply"
        # 调用相应的模块去处理
        apply(mod, func, args)
      rescue
        err -> IO.puts("#{module}:#{action} error: #{inspect(err)}")
      end
    else
      # Logger.debug "else"
      {:reply, {{module, action}, "action received"}}
    end
  end

  defp handle_result({:reply, response}, {_, session, _} = state) do
    GenServer.cast(session, {:reply, response})
    {:noreply, state}
  end

  defp handle_result({:notify, events, changed}, {id, session, data}) do
    {events, changed} = apply_rules({events, changed}, {id, data})
    GenServer.cast(session, {:notify, events})
    {:noreply, {id, session, merge({id, data}, changed)}}
  end

  defp handle_result({:resolve, context, effects}, {id, session, data}) do
    # apply partial resolved changes
    # Logger.debug "here2"
    # Logger.debug "handle_result({:resolve, context, effects}, {id, session, data}) do"
    # sell这一步没有起作用
    {resolved, data} = resolved(context, {id, data})

    # Logger.debug "effects : #{inspect effects, pretty: true}"
    # List.wrap(effects)
    # List.flatten(effects)
    {events, data} =
      effects
      # |> Enum.flat_map_reduce(data, fn effect, data ->
      |> Enum.map_reduce(data, fn effect, data ->
        {events, changed} = resolve(effect, {id, context, data})
        {List.wrap(events), merge({id, data}, changed)}
      end)

    # events 给了客户端，暂时不用管
    GenServer.cast(session, {:notify, resolved ++ events})
    {:noreply, {id, session, data}}
  end

  defp handle_result(:ok, state) do
    {:noreply, state}
  end

  defp resolved(context, {id, data}) when is_map(context) do
    Logger.debug(" resolved(context, {id, data}) when is_map(context) do")
    events = context |> Map.get(:events) |> List.wrap()
    changed = context |> Map.get(:changed, %{})

    {events, changed} = apply_rules({events, changed}, {id, data})
    {events, merge({id, data}, changed)}
  end

  defp resolved(_context, {_, data}) do
    # Logger.debug "resolved(_context, {_, data}) do"
    {[], data}
  end

  # TODO: check points => attrbutes => stats
  # TODO: build a pipeline based on changed props, then apply
  defp apply_rules({events, changed}, {id, data}) do
    {events, changed} =
      changed
      |> Enum.reduce({List.wrap(events), %{}}, fn change, {events, changed} ->
        change = Map.new([change])
        {new_events, new_changed} = Rules.apply_rule(change, {id, data})
        {events ++ List.wrap(new_events), changed |> Map.merge(new_changed)}
      end)

    {events, changed} =
      events
      |> Enum.reduce({events, changed}, fn event, {events, changed} ->
        # Rules.apply_rule( 目前什么都没有做
        {new_events, new_changed} = Rules.apply_rule(event, {id, data})
        {events ++ List.wrap(new_events), changed |> Map.merge(new_changed)}
      end)

    {events, changed}
  end

  # 什么事都没有做
  defp merge(data, nil) do
    data
  end

  # 改变的地方是一个map
  defp merge({id, data}, changed) when is_map(changed) do
    new_data = Map.merge(data, changed)
    Character.save(id, new_data)
    new_data
  end

  # 改变的地方是一个list
  defp merge({id, data}, changed) when is_list(changed) do
    new_data =
      changed
      |> Enum.reduce(data, fn
        # 更改data，access 路径为path 的值为value
        {path, value}, data -> data |> put_in(path, value)
      end)

    Character.save(id, new_data)
    new_data
  end

  defp resolve(effect, {id, context, data}) do
    Effect.resolve(effect, {id, context, data})
  end

  defp client_info({id, data}) do
    [["", id, data]]
  end

  @thirty_days_act_id 1055
  defp process_login({_id, _data} = state) do
    # Logger.debug "process_login data: #{inspect data, pretty: true}"
    now_time = Utils.timestamp()
    changed = Periods.ThirtyDays.check_reset(@thirty_days_act_id, now_time, state)
    merge(state, changed)
  end
end
