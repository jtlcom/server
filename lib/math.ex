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


  #每一级所需要的exp
  def level_exp(level) do 
    case level do 
      1 -> 10 
      2 -> 20 
      3 -> 40 
      4 -> 100 
      5 -> 250
      6 -> 500 
      7 -> 1000 
      8 -> -1 
    end 
  end

end
