defmodule Bag do
    @add_bag_gold 20
    @bag_key 2

    # 出售
    def sell(index, count, {_id, %{bag: bag}}) do
        with {item, stock} when stock >= count <- Inventory.get(bag, index),
            income <- Logical.sell(item.id) || []
        do
            income_effects = income |> Enum.map(fn {currency, price} -> {:gain, currency, price*count} end)
            lost_effects = {:lost, {:bag, index}, count}
            {:resolve, {:sell, {:bag, index}}, [lost_effects | income_effects]}
        else
            _ -> :ok
        end
    end

    # 一键出售
    def multi_sell(indices, {_id, %{bag: bag}}) do
        {lost_effects, incomes} = 
        indices |> Enum.reduce( {[], %{}}, fn index, {lost_effects, incomes} ->
            case Inventory.get(bag, index) do
                {_, 0} -> {lost_effects, incomes}
                {item, stock} ->
                    case Logical.sell(item.id) || []  do
                        [] -> {lost_effects, incomes}
                        income ->
                            { [{:lost, {:bag, index}, stock} | lost_effects],
                            income |> Enum.reduce(incomes, fn {currency, price}, incomes ->
                                Map.update(incomes, currency, price, &(&1 + price*stock)) end) }
                    end
            end
        end )
        income_effects =incomes |> Enum.map(fn {currency, amount} -> {:gain, currency, amount} end)
        {:resolve, :multi_sell, lost_effects ++ income_effects}
    end

    # 使用 
    def use(index, count, {_id, %{bag: bag, gene: gene} = data}) do
        with {%{id: item_id} = item, stock} <- Inventory.get(bag, index),
            true <- Action.match?(Logical.require(item_id), data),
            {action, rule} <- Logical.use(item_id),
            {requires, costs, rewards} <- declare(action, rule, {index, item, count}, gene),
            true <- Action.match?(requires, data) and Action.match?(costs, data)
        do
            {:resolve, {:use, {:bag, index}}, Effect.from_cost_rewards(costs, rewards)}
        else
            _ -> :ok
        end
    end

    # 经验丹
    defp declare(:exp, %{consume: consume?, params: [exp]}, {index, _item, count}, _gene) do
        item_cost =  {{:bag, index}, count}  
        reward = {:exp, exp * count}
        consumed(consume?, item_cost, reward)
    end

    # 经验药水
    defp declare(:exp_drug, %{consume: consume?, params: [_times, _sec] = params}, {index, _item, count}, _gene) do
        item_cost = {{:bag, index}, count}
        reward = {:gainExpSpeed, params, count}
        consumed(consume?, item_cost, reward)
    end

    # 挂机卡
    defp declare(:hook_time, %{consume: consume?, params: [times]}, {index, _item, count}, _gene) do
        item_cost = {{:bag, index}, count}
        reward = {:onHookTime, times * count}
        consumed(consume?, item_cost, reward)
    end

    # 铜币
    defp declare(:coin, %{consume: consume?, params: [amount]}, {index, _item, count}, _gene) do
        item_cost = {{:bag, index}, count}
        reward = {:coin, amount * count}
        consumed(consume?, item_cost, reward)
    end

    # 添加背包格子数
    defp declare(:bagCells, %{consume: consume?, params: [num]}, {index, item, count}, _gene) do
        stock = Map.get(item, :count, 0)
        add_sells = div(count, @bag_key)
        if stock >= count do
            item_cost = {{:bag, index}, add_sells * @bag_key}
        else
            cost_count = stock
            cost_gold = @add_bag_gold * (count - stock)
            item_cost = [ {{:bag, index}, cost_count}, {:gold, cost_gold} ]
        end
        reward = {:bagCells, num * add_sells }
        consumed(consume?, item_cost, reward)
    end

     # vip体验卡
    defp declare(:vip, %{consume: consume?, params: [_lv, _sec] = params}, {index, _item, count}, _gene) do
        item_cost = {{:bag, index}, count}
        reward = {:vip, params, count}
        consumed(consume?, item_cost, reward)
    end

    defp consumed(true, item_cost, reward), do: {[], List.flatten([item_cost]), reward}
    defp consumed(false, item_cost, reward), do: {[item_cost], [], reward}

end
