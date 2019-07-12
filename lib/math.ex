defmodule Math do
  def clamp(value, min, max) do
    value |> max(min) |> min(max)
  end

  def lerp(a, b, t) do
    a + (b - a) * t
  end

  def levelup(level, exp, fun) do
    case fun.(level) do
      nil -> {level, exp}   # max level reached
      -1 -> {level, 0}      # max level reached
      cost when cost > exp -> {level, exp}
      cost when cost == exp -> {level + 1, 0}
      cost -> levelup(level + 1, exp - cost, fun)
    end
  end
end
