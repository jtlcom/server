defmodule BattlePower do
  defdelegate merge(map1, map2), to: Map

  def all({id, data}) do
    {:notify, [{{:battle, :all}, id, %{battle_power: all(data)}}]}
  end

  def all(props) do
    detail(props) |> count()
  end

  def details({id, data}) do
    {:notify, [{{:battle, :details}, id, %{details: detail(data)}}]}
  end

  defp detail(props) do
    %{}
    |> merge(character(props))

    # |> merge(equipments(props))
  end

  defp count(details) do
    details
    |> Map.values()
    |> Enum.reduce(0, fn detail, acc ->
      acc + (detail[:all] || 0)
    end)
  end

  def character(info) do
    %{character: CharacterCompute.compute(info)}
  end

  def equipments(info) do
    %{equipments: EquipmentsCompute.compute(info)}
  end
end

# 人物相关计算
defmodule CharacterCompute do
  defdelegate merge(map1, map2), to: Map
  @unadorn -1

  def compute(info) do
    details =
      %{}
      |> merge(level(info[:level]))

    # |> merge(titles(info[:titles]))
    # |> merge(dresses(info[:dresses]))
    # |> merge(mount(info[:mount]))
    # |> merge(pet(info[:pet]))
    # |> merge(wing(info[:wing]))
    # |> merge(sword(info[:sword]))
    # |> merge(cloak(info[:cloak]))
    # |> merge(talisman(info[:talisman]))

    all = details |> Map.values() |> Enum.sum()
    Map.put(details, :all, all)
  end

  def level(level) do
    attribute = Level.level(level) |> Map.get(:attribute, %{})

    case level do
      0 ->
        %{level: 0}

      _ ->
        %{level: attributecompute(attribute)}
    end
  end

  def attributecompute(attribute) do
    attack_battlepower =
      ((attribute[:attack] || 0) + (attribute[:sunderArmor] || 0) + (attribute[:hitTarget] || 0) +
         (attribute[:criticalHit] || 0)) * 10

    defence_battlepower =
      (attribute[:life] || 0) * 0.5 +
        ((attribute[:defence] || 0) + (attribute[:evasion] || 0) + (attribute[:tenacity] || 0)) *
          10

    battle_power = attack_battlepower + defence_battlepower
  end

  def titles(%{title_id: title_id} = titles) do
    case title_id do
      @unadorn -> %{titles: 0}
      _ -> %{titles: Titles.config(title_id)[:battlePower]}
    end
  end

  def dresses(dresses) do
    %{dresses: 0}
  end

  def mount(mount) do
    %{mount: 0}
  end

  def pet(pet) do
    %{pet: 0}
  end

  def wing(wing) do
    %{wing: 0}
  end

  def sword(sword) do
    %{sword: 0}
  end

  def cloak(cloak) do
    %{cloak: 0}
  end

  def talisman(talisman) do
    %{talisman: 0}
  end
end

# 装备相关计算
defmodule EquipmentsCompute do
  def compute(%{equipments: equipments} = data) do
    init = %{all: 0, level: 0, enhanced: 0, additionProps: 0, gems: 0}

    case equipments do
      %{} ->
        init

      _ ->
        equipped =
          equipments
          |> Map.values()
          |> Enum.filter(fn value -> value != %{} end)

        case equipped do
          [] -> init
          _ -> handle(data)
        end

        # 待修改
    end
  end

  def handle(%{equipments: equipments} = data) do
    equiped =
      equipments
      |> Map.values()
      |> Enum.filter(fn value -> value != %{} end)

    details = %{
      level: level(equiped),
      enhanced: enhanced(equiped),
      additionProps: additionProps(equiped),
      gems: gems(equiped)
    }

    all = details |> Map.values() |> Enum.sum()
    Map.put(details, :all, all)
  end

  def level(equipments) do
    %{level: 0}
  end

  def enhanced(equipments) do
    %{enhanced: 0}
  end

  def additionProps(equipments) do
    %{additionProps: 0}
  end

  def gems(equipments) do
    %{gems: 0}
  end
end

defmodule Level do
  use GameDef

  # GameDef.defconf view: "actors/levels", getter: :level
  def level(_), do: 0
end
