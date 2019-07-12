defmodule Gm do
  def coin(amount, {id, %{currencies: %{coin: coin} = currencies}}) do
    new_coin = coin + amount
    {:notify, {:prop_changed, id, %{coin: new_coin}}, %{currencies: %{currencies | coin: new_coin}}}
  end

  def gold(amount, {id, %{currencies: %{gold: gold} = currencies}}) do
    new_gold = gold + amount
    {:notify, {:prop_changed, id, %{gold: new_gold}}, %{currencies: %{currencies | gold: new_gold}}}
  end
end
