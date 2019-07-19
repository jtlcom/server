defmodule Bag do
    @add_bag_gold 20
    @bag_key 2

    require Logger


    #只显示背包货币和银行货币
    def show_currencies( {_id , %{ bank: bank , currencies: currencies } } = _all ) do 
      IO.puts "currencies: #{inspect currencies } " 
      IO.puts "bank: #{inspect bank } "
    end 

    #只显示游戏背包
    def show_bag( {_id , %{bag: bag , currencies: currencies } } = _all ) do 
      Logger.debug "bag : #{inspect bag , pretty: true }" 
    end 

    #只显示等级、hp和exp
    def show_level( {_id , %{level: level , points: %{ exp: exp , hp: hp } } } = _all ) do 
      IO.puts "level : #{level } , exp : #{exp } , hp : #{hp } " 
    end

    #充值魔石 gold
    def recharge( count, {_id, %{ currencies: %{gold: gold} }} = _all) do
      #old_currencies = Map.get( currencies, currencyType, 0) 
      #Logger.debug "recharge 1 " 
      IO.puts "old => gold : #{gold} " 
      IO.puts "new => gold : #{gold+count} " 
      #income_effects = {:gain, currencyType, count}
      #income = %{gold: count }
      #income = income |> Enum.map(fn {currencyType, count} -> {:gain, currencyType, count} end) 
      #Logger.debug "income: #{inspect income , pretty: true }" 
      income_effects = [ {:gain, :gold, count} ]  
      #Logger.debug("recharge 2 ") 
      context = {:recharge, {:bag, count} } 
      effects = income_effects 

      {:resolve, context , effects } 
    end

    #花费 魔石:gold 买 金币:coin
    def change_for_coin( count,{_id, %{bag: bag, currencies: %{ gold: gold , coin: coin } }} ) do
      if gold >= count do 
        IO.puts "old => gold : #{gold} , coin : #{coin} " 
        IO.puts "new => gold : #{gold-count} , coin : #{coin+count*1000} " 

        lost_effects = [ {:lost , :gold , count } ] 
        income_effects = [ {:gain , :coin , count * 1000 } ] 

        context = {:change_for_coin , {:bag , count } } 
        effects = lost_effects ++ income_effects 

        {:resolve , context , effects } 
      else 
        IO.puts "Not enough gold ! " 
        :ok 
      end 
    end

    #将背包里的 金币:coin 存入银行
    def save2bank( count,{_id, %{bank: %{coin: bank_coin} , currencies: %{coin: currencies_coin } , currencies: currencies }} = _all ) do 
      if currencies_coin >= count do 
        IO.puts "old => currencies : #{currencies_coin} , bank : #{bank_coin} " 
        IO.puts "new => currencies : #{currencies_coin-count} , bank : #{bank_coin+count} " 

        lost_effects = [ { :lost , { :currencies , :coin} , count } ] 
        income_effects = [ { :gain , { :bank , :coin} , count } ] 

        context = { :save2bank , { :bag , count } } 
        effects = lost_effects ++ income_effects 

        {:resolve , context , effects } 
      else 
        IO.puts "Not enough coin ! " 
        :ok 
      end
    end

    #从银行中取出已存入的 金币:coin 
    def bank2bag( count,{_id, %{ bank: %{ coin: bank_coin } , currencies: %{ coin: currencies_coin } }} = _all ) do 
      if bank_coin >= count do 
        IO.puts "old => currencies : #{currencies_coin} , bank : #{bank_coin} " 
        IO.puts "new => currencies : #{currencies_coin+count} , bank : #{bank_coin-count} " 

        lost_effects = [ { :lost , { :bank , :coin } , count } ] 
        income_effects = [ { :gain , { :currencies , :coin } , count } ] 

        context = { :bank2bag , { :bag , count } } 
        effects = lost_effects ++ income_effects 

        { :resolve , context , effects } 
      else 
        IO.puts "Not enough coin ! " 
        :ok 
      end 
    end

    #角色吞噬装备 消耗物品和hp 获得exp
    def swallow_equip( index , count , currencyType \\ :bindGold , {_id, %{bag: bag, points: %{hp: hp , exp: exp } , level: level } } ) do 
      with {item , stock} when stock >= count <- Inventory.get(bag , index ) , 
        income <- Logical.swallow_equip(item.id) |> Map.take(List.wrap(currencyType) ) || [] 
      do 
        IO.puts "old => level : #{level} , exp : #{exp} " 
        lost_effects1 = [{:lost, {:bag, index}, count}] 
        lost_effects2 = [{:lost , {:points , :hp} , count } ] 
        lost_effects = lost_effects1 ++ lost_effects2 
        income_effects = income |> Enum.map(fn {currencyType, price} -> {:gain, {:points , :exp}, price*count} end)
        
        context = {:swallow_equip , {:bag, index} } 
        effects = lost_effects ++ income_effects 
        { :resolve , context , effects } 
      else 
        #IO.puts "Some error ! " 
        _ -> :ok 
      end 
    end

    #用于判定是否能够升级，主要调用了Math模块的levelup函数，并将返回值传回avatar解析
    def level_up?( {_id, %{level: level, points: %{exp: exp } }} = all ) do 
      {level, exp} = Math.levelup( level , exp ) 

      context = {:level_up? , {} } 
      effects = [ {:modify , level , exp } ]
      { :resolve , context , effects } 
    end 

    #将背包里的物品以一定的价格放入拍卖行 
    def bag2auction(index, count , money , {_id, %{bag: bag, auction: auction } } ) do 
      with {item, stock} <- Inventory.get(bag, index) , 
            true <-  Inventory.auction_can_store?(auction,item.id)  #判断仓库还能不能存放
      do 
        get_effects = [{:gain,:auction, {:item_id, item.id}, count , money }]
        lost_effects = [{:lost, {:bag, index}, count }]

        context = {:bag2auction , {:bag , index , count , money } } 
        effects = get_effects ++ lost_effects 
        { :resolve , context , effects } 
      else 
        _ -> :ok 
      end 
    end 





    #展示所有信息
    def show_all({_id, %{bag: bag, currencies: currencies}} = all) do
        Logger.debug "all: #{inspect all , pretty: true}"
    end

    # 出售 默认出售物品后获得:bindGold
    def sell(index, count,currencyType \\ :bindGold, {_id, %{bag: bag, currencies: currencies}} = _all) do
        # Logger.debug("sell ")
        # Logger.debug "all: #{inspect all, pretty: true}"
        # Logger.debug "bag: #{inspect bag, pretty: true}"
        # Logger.debug "currencies: #{inspect currencies, pretty: true}"
        with {item, stock} when stock >= count <- Inventory.get(bag, index), #获取bag中index物品的信息
            income <-  Logical.sell(item.id) |> Map.take(List.wrap(currencyType)) || [] 
            
            #从item获取物品相关信息（主要是这个物品各种货币应该卖多少钱）
        do
            # Logger.debug "item: #{inspect item, pretty: true}"
            # Logger.debug "item.id: #{inspect item.id, pretty: true}"
            Logger.debug "income: #{inspect income, pretty: true}"
            income_effects = income |> Enum.map(fn {currencyType, price} -> {:gain, currencyType, price*count} end) #计算卖出后的收益
            # Logger.debug "income_effects: #{inspect income_effects, pretty: true}"
            lost_effects = [{:lost, {:bag, index}, count}] #bag中减少的物品和数量
            {:resolve, {:sell, {:bag, index}}, lost_effects ++ income_effects}
        else
            _ -> :ok
        end
    end

    #选中背包的index进行购买 默认用:bindGold购买物品
    def buy(index, count,currencyType \\ :bindGold, {_id, %{bag: bag, currencies: currencies}} = _all) do
        # Logger.debug("sell ")
        # Logger.debug "all: #{inspect all, pretty: true}"
        # Logger.debug "bag: #{inspect bag, pretty: true}"
        # Logger.debug "currencies: #{inspect currencies, pretty: true}"
        with item <- Inventory.getItem(bag, index), #获取bag中index物品的信息
            totalmoney  <- Map.get( currencies, currencyType, 0), #获取角色当前currencyType \\ :bindGold这种货币还有多少
            price when totalmoney >= price * count  <-  Map.get( Logical.buy(item.id), currencyType, totalmoney + 1) 
            #获取买这个物品的单价，并判断自己这种货币currencyType \\ :bindGold 够不够

        do
            # Logger.debug "hhh"
            # # Logger.debug "item.id: #{inspect item.id, pretty: true}"
            # # Logger.debug "income: #{inspect income, pretty: true}"
            cost_effects = [{currencyType, price}] |> Enum.map(fn {currency, price} -> {:lost, currency, price*count} end) #计算买入所花的钱
            # Logger.debug "cost_effects: #{inspect cost_effects, pretty: true}"
            get_effects = [{:gain, {:item, item.id}, count}] #计算买入后的收益
            # Logger.debug "get_effects: #{inspect get_effects, pretty: true}"
            {:resolve, {:buy, {:bag, index}}, get_effects ++ cost_effects}
        else

            _ ->
                # Logger.debug "with out"

                :ok
        end
    end

    #将背包的某个物品全部存入仓库
    def bag2warehouse(index, {_id, %{bag: bag, warehouse: warehouse}} = _all) do
        # Logger.debug("bag2warehouse ")
        # Logger.debug "all: #{inspect all, pretty: true}"
        # Logger.debug "bag: #{inspect bag, pretty: true}"

        # Logger.debug "currencies: #{inspect currencies, pretty: true}"
        with {item, stock} <- Inventory.get(bag, index),   #获取bag中index物品的信息
            true <-  Inventory.warehouse_can_store?(warehouse,item.id)  #判断仓库还能不能存放
        do
            # Logger.debug "hhh"
            # Logger.debug "item: #{inspect item, pretty: true}"
            # Logger.debug "item.id: #{inspect item.id, pretty: true}"
            # Logger.debug "income: #{inspect income, pretty: true}"
            # income_effects = income |> Enum.map(fn {currency, price} -> {:gain, currency, price*count} end)
            get_effects = [{:gain,:warehouse, {:item_id, item.id}, stock}] #仓库中多的

            # Logger.debug "income_effects: #{inspect income_effects, pretty: true}"
            lost_effects = [{:lost, {:bag, index}, stock}] #bag中少的

            {:resolve, {:sell, {:bag, index}}, lost_effects ++ get_effects }
        else

            _ ->
                Logger.debug "bag2warehouse else"
                :ok
        end
    end


        #将仓库的某个物品全部存入背包
        def warehouse2bag(index, {_id, %{bag: bag, warehouse: warehouse, bagCells: bagCells}} = _all) do
            # Logger.debug("warehouse2bag ")
            # Logger.debug "all: #{inspect all, pretty: true}"
            # Logger.debug "bag: #{inspect bag, pretty: true}"

            # Logger.debug "currencies: #{inspect currencies, pretty: true}"

            with {item, stock} <- Inventory.get(warehouse.bag, index), #获取bag中index物品的信息
                true <-  Inventory.bag_can_store?(bag,bagCells,item.id) #判断bag还能不能存放
            do
                # Logger.debug "hhh"
                # Logger.debug "item: #{inspect item, pretty: true}"
                # Logger.debug "item.id: #{inspect item.id, pretty: true}"
                # Logger.debug "income: #{inspect income, pretty: true}"
                # income_effects = income |> Enum.map(fn {currency, price} -> {:gain, currency, price*count} end)
                # get_effects = [{:gain,:warehouse, {:item_id, item.id}, stock}]

                get_effects = [{:gain, {:item, item.id}, stock}]  #bag 获取东西
                # Logger.debug "income_effects: #{inspect income_effects, pretty: true}"
                # lost_effects = [{:lost, {:bag, index}, stock}]
                lost_effects = [{:lost,:warehouse, {:item_id, item.id}, stock}] #仓库中少的

                {:resolve, {:sell, {:bag, index}}, lost_effects ++ get_effects }
            else

                _ ->
                    # Logger.debug "bag2warehouse else"
                    :ok
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
            # Action.match?  判断requirements （需要的条件） ，data是否满足，requirement可以是bag的东西，玩家等级（level），vip等级或其他属性
            {action, rule} <- Logical.use(item_id),      #获取使用该物品的规则
            {requires, costs, rewards} <- declare(action, rule, {index, item, count}, gene), #解析出 需要的条件和消耗的物品和收益
            true <- Action.match?(requires, data) and Action.match?(costs, data)  #再次判断条件是否符合
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
        item_cost =
        if stock >= count do
            {{:bag, index}, add_sells * @bag_key}
        else
            cost_count = stock
            cost_gold = @add_bag_gold * (count - stock)
            [ {{:bag, index}, cost_count}, {:gold, cost_gold} ]
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

    defp consumed(true, item_cost, reward), do: {[], List.flatten([item_cost]), reward} #表示该物品为消耗品，用了就没了
    defp consumed(false, item_cost, reward), do: {[item_cost], [], reward}   #表示该物品为非消耗品，用了不减少bag中的东西，只匹配requirement（此处第一个返回值） 是否满足

end
