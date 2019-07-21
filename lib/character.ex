defmodule Character do
  require Logger

  def create(account_id, name, gene) do
    avatar_id = Repo.next_id(:character)
    Repo.insert(:character, {avatar_id, account_id, name, %{gene: gene}})
#创建角色时并没有初始化或载入角色数据
    {:ok, avatar_id}
  end

  def list(account_id) do
    Repo.list_characters(account_id)
    |> Enum.map(fn([id, name, data]) -> [id, name, data[:gene], data[:level], %{}] end)
  end

  #导入角色数据（第一次会给角色初始化数据）
  def load(avatar_id, vsn \\ 0) do #avatar 调用时 vsn = 1
  # Logger.debug "Character -> load(avatar_id, vsn \\ 0)"
    data = Repo.load(:character, avatar_id)
    Logger.debug "between"
    Logger.debug "data-chararcter: #{ inspect data, pretty: true }"
    Repo.migrate(:character, vsn, data)
    # Logger.debug "Character -> load(avatar_id, vsn \\ 0)  end"
  end

  def save(avatar_id, data) do
    Repo.save(:character, avatar_id, data)
  end

end
