defmodule Realm do
  def start_avatar(avatar_id, session) do
    Avatar.Supervisor.start_child {avatar_id, session}, name: Guid.name(avatar_id)
  end

  def control(avatar_pid, request) when is_pid(avatar_pid) do
    GenServer.cast(avatar_pid, request)
  end

  def control(avatar_id, request) do
    Router.cast(avatar_id, request)
  end
end
