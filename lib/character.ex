defmodule Character do
  require Logger

  def create(account_id, name, gene) do
    avatar_id = Repo.next_id(:character)
    Repo.insert(:character, {avatar_id, account_id, name, %{gene: gene}})

    {:ok, avatar_id}
  end

  def list(account_id) do
    Repo.list_characters(account_id)
    |> Enum.map(fn([id, name, data]) -> [id, name, data[:gene], data[:level], %{}] end)
  end

  def load(avatar_id, vsn \\ 0) do
    data = Repo.load(:character, avatar_id)
    Repo.migrate(:character, vsn, data)
  end

  def save(avatar_id, data) do
    Repo.save(:character, avatar_id, data)
  end

end
