defmodule Repo do
  @character_table :characters

  def init() do
    :dets.open_file(@character_table, [])
  end

  def insert(:character, character) do
    :dets.insert(@character_table, character)
  end

  def list_characters(account_id) do
    :dets.match(@character_table, {:'$0', account_id, :'$1', :'$2'})
  end

  def load(:character, id) do
    [{_, account_id, name, data}] = :dets.lookup(@character_table, id)
    data |> Map.merge(%{account_id: account_id, name: name})
  end

  def save(:character, id, character) do
    {%{account_id: account_id, name: name}, data} = Map.split(character, [:account_id, :name])
    :dets.insert(@character_table, {id, account_id, name, data})
  end

  def migrate(:character, vsn, character) do
    case Map.get(character, :vsn, 0) do
      0 ->
        character
        |> Map.merge(%{level: 1,
                       stats: %{},
                       points: %{hp: 100, exp: 0},
                       currencies: %{coin: 10000, gold: 1000},
                       pos: %{map: 1, x: 10, y: 10},
                       bag: %{},
                       warehouse: %{},
                       vip: %{level: 0, exp: 0},
                       vsn: vsn
                    })
      ^vsn -> character
      _ -> character
    end
  end

  def next_id(:character) do
    :dets.info(@character_table, :no_objects) + 1
  end

  def close() do
    :dets.close(@character_table)
  end

end
