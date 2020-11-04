defmodule Math do
  def levelup(level, exp, fun) do
    case fun.(level) do
      # max level reached
      nil -> {level, exp}
      # max level reached
      -1 -> {level, 0}
      cost when cost > exp -> {level, exp}
      cost when cost == exp -> {level + 1, 0}
      cost -> levelup(level + 1, exp - cost, fun)
    end
  end
end
