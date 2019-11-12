defmodule Bag do
  @add_bag_gold 20
  @bag_key 2

  require Logger

  # 展示所有信息
  def show_bag({_id, %{bag: _bag, currencies: _currencies}} = all) do
    Logger.debug("all: #{inspect(all, pretty: true)}")
  end

  # 出售 默认出售物品后获得:bindGold
  def sell(index, count, currencyType \\ :bindGold, {_id, %{bag: bag, currencies: _currencies}} = _data) do
    # 获取bag中index物品的信息
    with {item, stock} when stock >= count <- Inventory.get(bag, index),
         # 从item获取物品相关信息（主要是这个物品各种货币应该卖多少钱）
         income <- Logical.sell(item.id) |> Map.take(List.wrap(currencyType)) do
      # 计算卖出后的收益
      income_effects =
        income |> Enum.map(fn {currency, price} -> {:gain, currency, price * count} end)

      # bag中减少的物品和数量
      lost_effects = [{:lost, {:bag, index}, count}]
      context = %{action: {:bag, :sell}, events: {:sell, {:bag, index}}, changed: %{}}
      # 将消息发给avatar，avatar对玩家数据进行修改
      {:resolve, context, Effect.from_cost_rewards(lost_effects, income_effects)}
    else
      _ -> :ok
    end
  end

  # 选中背包的index进行购买 默认用:bindGold购买物品
  def buy(index, count, currencyType \\ :bindGold, {_id, %{bag: bag, currencies: currencies}} = _data) do
    # Logger.debug("sell ")
    # Logger.debug "all: #{inspect all, pretty: true}"
    # Logger.debug "bag: #{inspect bag, pretty: true}"
    # Logger.debug "currencies: #{inspect currencies, pretty: true}"
    # 获取bag中index物品的信息
    with item <- Inventory.getItem(bag, index),
         # 获取角色当前currencyType \\ :bindGold这种货币还有多少
         totalmoney <- Map.get(currencies, currencyType, 0),
         # 获取买这个物品的单价，并判断自己这种货币currencyType \\ :bindGold 够不够
         price when totalmoney >= price * count <-
           Map.get(Logical.buy(item.id), currencyType, totalmoney + 1) do
      # Logger.debug "hhh"
      # # Logger.debug "item.id: #{inspect item.id, pretty: true}"
      # # Logger.debug "income: #{inspect income, pretty: true}"
      # 计算买入所花的钱
      cost_effects =
        [{currencyType, price}]
        |> Enum.map(fn {currency, price} -> {:lost, currency, price * count} end)

      # Logger.debug "cost_effects: #{inspect cost_effects, pretty: true}"
      # 计算买入后的收益
      get_effects = [{:gain, {:item, item.id}, count}]
      context = %{action: {:bag, :buy}, events: {:buy, {:bag, index}}, changed: %{}}
      {:resolve, context, Effect.from_cost_rewards(cost_effects, get_effects)}
    else
      _ ->
        # Logger.debug "with out"

        :ok
    end
  end

  # 将背包的某个物品全部存入仓库
  def bag2warehouse(index, {_id, %{bag: bag, warehouse: warehouse}} = _data) do
    # 获取bag中index物品的信息
    with {item, stock} <- Inventory.get(bag, index),
         # 判断仓库还能不能存放
         true <- Inventory.warehouse_can_store?(warehouse, item.id) do
      # 仓库中多的
      get_effects = [{:gain, :warehouse, {:item_id, item.id}, stock}]

      # bag中少的
      lost_effects = [{:lost, {:bag, index}, stock}]
      context = %{action: {:bag, :bag2warehouse},
                  events: {:bag2warehouse, {:bag, index}},
                  changed: %{}}
      {:resolve, context, Effect.from_cost_rewards(lost_effects, get_effects)}
    else
      _ ->
        Logger.debug("bag2warehouse else")
        :ok
    end
  end

  # 将仓库的某个物品全部存入背包
  def warehouse2bag(index, {_id, %{bag: bag, warehouse: warehouse, bagCells: bagCells}} = _data) do
    # 获取bag中index物品的信息
    with {item, stock} <- Inventory.get(warehouse.bag, index),
         # 判断bag还能不能存放
         true <- Inventory.bag_can_store?(bag, bagCells, item.id) do
      # bag 获取东西
      get_effects = [{:gain, {:item, item.id}, stock}]
      # 仓库中少的
      lost_effects = [{:lost, :warehouse, {:item_id, item.id}, stock}]
      context = %{action: {:bag, :warehouse2bag},
                  events: {:warehouse2bag, {:bag, index}},
                  changed: %{}}
      {:resolve, context, Effect.from_cost_rewards(lost_effects, get_effects)}
    else
      _ ->
        # Logger.debug "bag2warehouse else"
        :ok
    end
  end

  # 一键出售
  def multi_sell(indices, {_id, %{bag: bag}}) do
    {lost_effects, incomes} =
      indices
      |> Enum.reduce({[], %{}}, fn index, {lost_effects, incomes} ->
        case Inventory.get(bag, index) do
          {_, 0} ->
            {lost_effects, incomes}

          {item, stock} ->
            case Logical.sell(item.id) || [] do
              [] ->
                {lost_effects, incomes}

              income ->
                {[{:lost, {:bag, index}, stock} | lost_effects],
                 income
                 |> Enum.reduce(incomes, fn {currency, price}, incomes ->
                   Map.update(incomes, currency, price, &(&1 + price * stock))
                 end)}
            end
        end
      end)

    income_effects = incomes |> Enum.map(fn {currency, amount} -> {:gain, currency, amount} end)
    {:resolve, :multi_sell, Effect.from_cost_rewards(lost_effects, income_effects)}
  end

  # 使用
  def use(index, count, {_id, %{bag: bag, gene: gene} = data}) do
    with {%{id: item_id} = item, _stock} <- Inventory.get(bag, index),
         # Action.match?  判断requirements （需要的条件） ，data是否满足，requirement可以是bag的东西，玩家等级（level），vip等级或其他属性
         true <- Action.match?(Logical.require(item_id), data),
         # 获取使用该物品的规则
         {action, rule} <- Logical.use(item_id),
         # 解析出 需要的条件和消耗的物品和收益
         {requires, costs, rewards} <- declare(action, rule, {index, item, count}, gene),
         # 再次判断条件是否符合
         true <- Action.match?(requires, data) and Action.match?(costs, data) do
      {:resolve, {:use, {:bag, index}}, Effect.from_cost_rewards(costs, rewards)}
    else
      _ -> :ok
    end
  end

  # 经验丹
  defp declare(:exp, %{consume: consume?, params: [exp]}, {index, _item, count}, _gene) do
    item_cost = {{:bag, index}, count}
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

    item_cost =
      if stock >= count do
        {{:bag, index}, add_sells * @bag_key}
      else
        cost_count = stock
        cost_gold = @add_bag_gold * (count - stock)
        [{{:bag, index}, cost_count}, {:gold, cost_gold}]
      end

    reward = {:bagCells, num * add_sells}
    consumed(consume?, item_cost, reward)
  end

  # vip体验卡
  defp declare(:vip, %{consume: consume?, params: [_lv, _sec] = params}, {index, _item, count}, _gene) do
    item_cost = {{:bag, index}, count}
    reward = {:vip, params, count}
    consumed(consume?, item_cost, reward)
  end

  # 表示该物品为消耗品，用了就没了
  defp consumed(true, item_cost, reward), do: {[], List.flatten([item_cost]), reward}

  # 表示该物品为非消耗品，用了不减少bag中的东西，只匹配requirement（此处第一个返回值） 是否满足
  defp consumed(false, item_cost, reward), do: {[item_cost], [], reward}
end
