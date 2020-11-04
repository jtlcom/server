defmodule Gm do
  def coin(amount, {id, %{currencies: %{coin: coin} = currencies}}) do
    new_coin = coin + amount

    {:notify, {:prop_changed, id, %{coin: new_coin}},
     %{currencies: %{currencies | coin: new_coin}}}
  end

  def gold(amount, {id, %{currencies: %{gold: gold} = currencies}}) do
    new_gold = gold + amount

    {:notify, {:prop_changed, id, %{gold: new_gold}},
     %{currencies: %{currencies | gold: new_gold}}}
  end

  def add_item(item_id, count, _state) do
    {:resolve, :gm, {:gain, {:item, item_id}, count}}
  end

  def delete_item(item_id, count, _state) do
    {:resolve, :gm, {:lost, {:item, item_id}, count}}
  end

  def exp(amount, {id, %{points: %{exp: exp} = points}}) do
    new_exp = amount + exp
    {:notify, {:prop_changed, id, %{exp: new_exp}}, %{point: %{points | exp: new_exp}}}
  end

  def vip(lv, {id, %{vip: vip}}) do
    vip = vip |> Map.put(:level, lv)
    {:notify, {:prop_changed, id, %{vip: vip}}, %{vip: vip}}
  end

  def bind_gold(amount, {id, %{currencies: %{bindGold: bindGold} = currencies}}) do
    new_bindGold = bindGold + amount

    {:notify, {:prop_changed, id, %{bindGold: new_bindGold}},
     %{currencies: %{currencies | bindGold: new_bindGold}}}
  end

  def clear({id, %{bag: bag}}) do
    {:notify, [{:prop_changed, id, %{bag: %{}}}], %{bag: %{}}}
  end

  def clear(item_id, {id, %{bag: bag}}) do
    stock = Inventory.count(bag, item_id)
    {:resolve, :gm, {:lost, {:item, item_id}, stock}}
  end
end
