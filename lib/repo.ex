defmodule Repo do
  @character_table :character
  @init_cells 80
  @warehouse_init_cells 60
  require Logger

  def getinfo() do
    :dets.info(@character_table)
  end

  def init() do
    :dets.open_file(@character_table, [])
  end

  def insert(:character, character) do
    :dets.insert(@character_table, character)
  end

  def list_characters(account_id) do
    :dets.match(@character_table, {:"$0", account_id, :"$1", :"$2"})
  end

  # 导入角色数据（若是第一次导入，只包含很少的数据）

  def load(:character, id) do
    # {avatar_id, account_id, name, %{gene: gene}}  创建角色时的数据
    [{_, account_id, name, data}] = :dets.lookup(@character_table, id)
    # 把account_id , name 这两条数据合到data中
    data |> Map.merge(%{account_id: account_id, name: name})
    # Logger.debug "Repo -> load(:character, id) end"
  end

  def save(:character, id, character) do
    # Logger.info "repo save character is #{inspect character, pretty: true}"
    # data保存除去account_id和name之外的数据
    {%{account_id: account_id, name: name}, data} = Map.split(character, [:account_id, :name])
    :dets.insert(@character_table, {id, account_id, name, data})
  end

  # 为第一次加载的角色初始化数据
  # 如果character中的 vsn 为0，则创建character的数据 其中vsn为传进来的vsn
  def migrate(:character, vsn, character) do
    Logger.debug(
      "Repo -> migrate(:character, vsn, character) do vsn is #{inspect(vsn)}, character_vsn is #{
        inspect(Map.get(character, :vsn, 0))
      }"
    )

    # 如果character中的 vsn 为传进来的vsn，则不对character数据做修改
    character =
      case Map.get(character, :vsn, 0) do
        # 新角色第一次加载数据
        0 ->
          character
          |> Map.merge(%{
            level: 1,
            stats: %{},
            points: %{hp: 100, exp: 0},
            currencies: %{coin: 10000, gold: 1000, bindGold: 1_000_000},
            pos: %{map: 1, x: 10, y: 10},
            bag: %{
              0 => %{id: 3, count: 1000},
              1 => %{id: 1, count: 1000},
              2 => %{id: 2, count: 1000},
              3 => %{id: 4, count: 1000},
              4 => %{id: 5, count: 1000},
              5 => %{id: 6, count: 1000},
              6 => %{count: 1000, id: 1001},
              7 => %{count: 1000, id: 1002},
              8 => %{count: 1000, id: 201},
              9 => %{count: 1000, id: 202},
              10 => %{count: 1000, id: 203},
              11 => %{count: 1000, id: 301},
              12 => %{count: 1000, id: 401},
              13 => %{count: 1000, id: 501},
              14 => %{count: 1000, id: 802},
              15 => %{count: 1000, id: 810}
            },
            bagCells: @init_cells,
            warehouse: %{max: @warehouse_init_cells, bag: %{}},
            vip: %{level: 0, exp: 0, sec: -1},
            vsn: 1,
            gainExpSpeed: %{speed: 1, sec: 0},
            onHookTime: 0,
            mount: %{
              mount_id: 1,
              blessing: 0,
              beast_soul: %{201 => 5, 202 => 400},
              actived: %{101 => 0},
              hh: 0
            },
            pet: %{
              pet_id: 1,
              blessing: 0,
              exp: 0,
              beast_soul: %{201 => 5, 202 => 400},
              actived: %{101 => 0},
              hh: 0
            },
            dresses: %{actived: %{802 => 0}, exp: 0}
          })

        1 ->
          character |> Map.put(:periods, %{}) |> Map.put(:vsn, 2)

        ## 2 -> character |> Map.put(:d, 0) |> Map.put(:vsn, 3)
        ## 3 -> character |> Map.put(:e, 0) |> Map.put(:vsn, 4)
        ^vsn ->
          character

        _ ->
          character
      end

    if Map.get(character, :vsn, 0) != vsn do
      migrate(:character, vsn, character)
    else
      character
    end

    ## 此处##注释的部分可用于动态更新角色的信息
  end

  def next_id(:character) do
    :dets.info(@character_table, :no_objects) + 1
  end

  def close() do
    :dets.close(@character_table)
  end
end
