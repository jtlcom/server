defmodule Session do
  use GenServer
  require Logger
  @behaviour :ranch_protocol

  @timeout :infinity
  @batch 15

  def log(msg, data) do
    File.write("log.txt", "#{inspect msg}\n#{inspect data}\n\n", [:append])
    # IO.inspect msg
    # IO.inspect data
  end

  def start_link(ref, socket, transport, opts) do
    {:ok, :proc_lib.spawn_link(__MODULE__, :init, [{ref, socket, transport, opts}])}
  end

  # 利用session去处理:ranch收到的连接，一些初始化信息
  def init({ref, socket, transport, _opts}) do
    Logger.debug("session init({ref, socket, transport, _opts})")
    ###################
    :ok = :proc_lib.init_ack({:ok, self()})
    #####################
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [active: @batch, packet: 2])

    state = %{socket: socket, transport: transport, state: :wait_auth}
    loop(socket, transport)
    :gen_server.enter_loop(__MODULE__, [], state, @timeout) #session被转化成立GenServer的模式
  end

  # Handle avatar process restart
  def handle_cast({:ack, avatar_pid}, %{state: :playing} = state) do
    Logger.debug("handle_cast({:ack, avatar_pid}, %{state: :playing} = state)")
    {:noreply, %{state | avatar_pid: avatar_pid}}
  end

  def handle_cast(:logout, %{state: :playing} = state) do
    Logger.debug("handle_cast(:logout, %{state: :playing} = state)")
    {:noreply, %{state | state: :authed, avatar_pid: nil, avatar_id: nil}}
  end

  def handle_cast({:reply, reply}, %{state: :playing, transport: transport, socket: socket} = state) do
    reply |> deliver(transport, socket)
    {:noreply, state}
  end

  def handle_cast({:notify, events}, %{state: :playing, transport: transport, socket: socket} = state) do
    {:event, List.wrap(events) |> Enum.map(&Tuple.to_list/1)} |> deliver(transport, socket)
    {:noreply, state}
  end
  def handle_cast(_, %{state: :playing, transport: transport, socket: socket} = state) do
    Logger.debug("handle_cast(_, %{state: :playing, transport: transport, socket: socket} = state)")
    {:noreply, state}
  end

  #客户端发送的socket信息会传到这里来（不过我目前没事有测试成功：2019/5/13）
  def handle_info({:tcp, socket, packet}, %{transport: transport} = state) do
    Logger.debug "receive client "
    Logger.debug " client packet is : #{inspect packet, pretty: true}"
    IO.puts packet
    {:ok, type, msg} = packet |> decode

    Logger.debug "receive client socket msg, type is #{inspect type}, msg is #{inspect msg}"
    if type != :ping and type != :move and type != :stop do
      log("recv msg", {type, msg})
    end
    case handle_request(type, msg, state) do
      {:reply, response, new_state} ->
        response |> deliver(transport, socket)
        {:noreply, new_state, @timeout}
      {:noreply, new_state} ->
        {:noreply, new_state, @timeout}
    end
  end

  def handle_info({:tcp_passive, socket}, %{transport: transport} = state) do
    Logger.debug "handle_info({:tcp_passive, socket}, %{transport: transport} = state)"
    transport.setopts(socket, [active: @batch])
    {:noreply, state, @timeout}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.debug "connection closed!"
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.debug "handle_info({:tcp_error, _socket, reason}, state)"

    {:stop, reason, state}
  end

  def handle_info(:timeout, state) do
    Logger.debug "handle_info(:timeout, state)"
    {:stop, :normal, state}
  end


  def handle_info(:loop, %{transport: transport, socket: socket} = state) do
    Logger.debug(" handle_info(:loop, state) ")

    loop(socket, transport)
    {:stop, :normal, state}
  end

  def handle_info(_, state) do
    Logger.debug("handle_info(_, state)")
    {:stop, :normal, state}
  end

  #####

  def processinfo(msg, delay \\ 0) do
    Logger.debug(" processinfo(msg, delay \\ 0) do ")
    Process.send_after(__MODULE__, msg, delay)
  end

  def loop(socket, transport) do
    Logger.debug "loop(socket, transport)"
    Logger.debug "socket: #{inspect socket, pretty: true}"
    Logger.debug "transport: #{inspect transport, pretty: true}"
    transport.send(socket, "hello")
    case transport.recv(socket, 0, 10000) do
      {:ok, data} ->
        transport.send(socket, data)
        # loop(socket, transport)
        Logger.debug "loop transport.send"
      _ ->
        #:ok = transport.close(socket)
        #loop(socket, transport)
        Logger.debug "loop exit"
    end
  end
  ######



  def terminate(_reason, %{state: :playing, avatar_pid: avatar_pid}) do
    Logger.debug("terminate(_reason, %{state: :playing, avatar_pid: avatar_pid})")
    GenServer.cast(avatar_pid, {:logout, []})
  end

  def terminate(reason, state) do
    super(reason, state)
  end

  defp handle_request(:ping, [seq], state) do
    {:reply, {:pong, [seq, System.system_time(:second)]}, state}
  end

  defp handle_request({:account, :auth}, [account], %{state: :wait_auth} = state) do
    {:ok, account_id} = Account.auth(account)
    # TODO: kick other sessions belongs to this account

    {:reply, {{:account, :auth}, "ok"}, %{state | state: :authed} |> Map.put_new(:account_id, account_id)}
  end

  defp handle_request({:character, :list}, [], %{state: :authed, account_id: account_id} = state) do
    characters = Character.list(account_id)
    {:reply, {{:character, :list}, [characters]}, state}
  end

  defp handle_request({:character, :create}, [name, gene], %{state: :authed, account_id: account_id} = state) do
    {:ok, id} = Character.create(account_id, name, gene)
    {:reply, {{:character, :create}, id}, state}
  end

  defp handle_request(:login, [login_token], %{state: :authed} = state) do
    # TODO: check login token, prevent from other account's avatar_id
    avatar_id = login_token

    case Guid.online?(avatar_id) do
      true ->
        Logger.debug "重复登录账号。。。。。"
        Router.route avatar_id, {:logout, "duplicate avatar"}
        :timer.sleep 1000
      _ ->
        :ok
    end

    {:ok, avatar_pid} = Realm.start_avatar avatar_id, self()  #!!!!!!!!self()是session的pid    在此传给avatar!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    GenServer.cast(avatar_pid, {:login, []})

    {:noreply, %{state | state: :playing}
               |> Map.put(:avatar_id, avatar_id)
               |> Map.put(:avatar_pid, avatar_pid)}
  end
#向avatar发消息
  defp handle_request(request, msg, %{state: :playing, avatar_pid: avatar_pid} = state) do
    Logger.debug "GenServer.cast(avatar_pid, {request, msg})"
    GenServer.cast(avatar_pid, {request, msg})
    {:noreply, state}
  end

  # TODO: remove reply message
  defp handle_request(request, _msg, state) do
    {:reply, {request, "unknown or invalid message type"}, state}
  end

  defp deliver({type, msg}, transport, socket) do
    if type != :pong do
      log("res msg", {type, msg})
    end
    {:ok, output} = encode {type, msg}
    transport.send(socket, output)
  end

  defp deliver(packet, transport, socket) when is_binary(packet) do
    transport.send(socket, packet)
  end

  alias Poison.Parser
  alias Poison.Encoder

  defp decode(packet) do
    [type | msg] = Parser.parse!(packet)
    {:ok, to_atom(type), msg}
  end

  defp encode({id, msg}) do
    encode([id | List.wrap(msg)])
  end

  defp encode(msg) do
    {:ok, Encoder.encode(msg, [])}
  end

  defp to_atom(type) do
    require Utils

    case String.split(type, ":", parts: 2, trim: true) do
      [module, action] -> {Utils.to_atom(module), Utils.to_atom(action)}
      [action] -> Utils.to_atom(action)
    end
  end

end








defimpl Poison.Encoder, for: Tuple do
  def encode({a, b}, options) when is_atom(a) and is_atom(b) do
    Poison.Encoder.BitString.encode("#{a}:#{b}", options)
  end

  def encode({a, b, c}, options) when is_atom(a) and is_atom(b) and is_atom(c) do
    Poison.Encoder.BitString.encode("#{a}:#{b}:#{c}", options)
  end
end
