defmodule Effect do

  require Logger

  #解析出消耗物品的格式
  def from_cost(cost) when is_tuple(cost) do
    List.wrap(cost) |> from_cost
  end

   #解析出消耗物品的格式
  def from_cost(cost) do
    cost |> Enum.map(fn
      {:item, id, count} -> {:lost, {:item, id}, count}
      {{:bag, index}, count} -> {:lost, {:bag, index}, count}
      {point, amount} -> {:lost, point, amount}
    end)
  end

  #解析出 收益的格式
  def from_rewards(rewards) when is_tuple(rewards) do
    List.wrap(rewards) |> from_rewards
  end

  #解析出 收益的格式
  def from_rewards(rewards) do
    rewards |> Enum.map(fn
      {:item, id, count} -> {:gain, {:item, id}, count}
      {:gainExpSpeed, [times, sec], count} -> {:gainExpSpeed, times, sec * count}
      {:vip, [lv, sec], count} -> {:vip, lv, sec * count}
      {point, amount} -> {:gain, point, amount}
      reward -> reward
    end)
  end

  #把 花费和收益的格式解析出来，再合并到一个list
  def from_cost_rewards(cost, rewards) do
    Enum.concat from_cost(cost), from_rewards(rewards)
  end


  #未对_context做处理  _context对应bag  :sell  /:buy
  def resolve({:gain, :item, item}, {id, _context, %{bag: bag}}) do
    {cell, bag} = bag |> Inventory.store(item)
    event = {{:bag, :gain}, id, %{cell => item}}
    {event, %{bag: bag}}
  end

  #给warehouse增加物品
  def resolve({:gain, :warehouse,{:item_id, item_id}, count}, {id, _context, %{warehouse: warehouse}}) do
    Logger.debug "warehouse resolve({:gain, {:item_id, item_id}, count}, {id, _context, %{bag: bag}}) do"
    %{bag: bag} = warehouse
    {cells, bag} = bag |> Inventory.stack(item_id, count, warehouse.max)
    warehouse = Map.put(warehouse, :bag, bag)

    {{{:warehouse, :gain}, id, Map.new(cells)}, %{warehouse: warehouse}}
  end

    #给bag增加物品
    def resolve({:gain, {:item, item_id}, count}, {id, _context, %{bag: bag}}) do
      Logger.debug "resolve({:gain, {:item, item_id}, count}, {id, _context, %{bag: bag}}) do"
      {cells, bag} = bag |> Inventory.stack(item_id, count)

      {{{:bag, :gain}, id, Map.new(cells)}, %{bag: bag}}
    end

  def resolve({:gain, {mod, prop}, amount}, {id, _context, data}) do
    with group when not is_nil(group) <- Map.get(data, mod),
      original when not is_nil(original) <- Map.get(group, prop),
      current = original + amount
    do
      {{:prop_changed, id, %{mod => %{prop => current}}}, %{mod => %{group | prop => current}}}
    else
      _ -> {[], %{}}
    end
  end

  #增加货币、hp、exp
  def resolve({:gain, prop, amount}, {id, _context, %{currencies: currencies, points: points}}) do
    Logger.debug "resolve({:gain, prop, amount}, {id, _context, %{currencies: currencies, points: points}}) do"
    if Map.has_key?(currencies, prop) do
      current = Map.get(currencies, prop) + amount
      {{:prop_changed, id, %{prop => current}}, %{currencies: %{currencies | prop => current}}}  
      #这一部分修改金币

    else
      if Map.has_key?(points, prop) do
        current = Map.get(points, prop) + amount
        {{:prop_changed, id, %{prop => current}}, %{points: %{points | prop => current}}} 
        #这一部分修改points  -》   points: %{hp: 100, exp: 0},
      end
    end
  end


  #角色经验升级系统
  def resolve( {:modify , level , exp } , {id, _context, %{level: _lv, points: points } } ) do 
    new_level = level
    new_points = %{points | exp: exp } 
    map = %{level: new_level, points: new_points } 
    {{:prop_changed, id, map }, map }
  end 


  def resolve({:lost, {:bag, index}, count}, {id, _context, %{bag: bag}}) do
    {lost, bag} = Inventory.pop_some_at(bag, index, count)
    {{{:bag, :lost}, id, %{index => lost}}, %{bag: bag}}
  end

  def resolve({:lost, {:item, item_id}, count}, {id, _context, %{bag: bag}}) do
    {^count, poped, bag} = Inventory.pop_some(bag, item_id, count)
    {{{:bag, :lost}, id, Map.new(poped)}, %{bag: bag}}
  end

  def resolve({:lost, :warehouse,{:item_id, item_id}, count}, {id, _context, %{warehouse: warehouse}}) do
    Logger.debug "warehouse resolve({:lost, {:item_id, item_id}, count}, {id, _context, %{bag: bag}}) do"
    %{bag: bag} = warehouse
    # {cells, bag} = bag |> Inventory.stack(item_id, count, warehouse.max)
    # warehouse = Map.put(warehouse, :bag, bag)

    # {{{:warehouse, :gain}, id, Map.new(cells)}, %{warehouse: warehouse}}


    {^count, poped, bag} = Inventory.pop_some(bag, item_id, count)
    warehouse = Map.put(warehouse, :bag, bag)
    {{{:warehouse, :lost}, id, Map.new(poped)}, %{warehouse: warehouse}}
  end

  def resolve({:lost, {mod, prop}, amount}, {id, _context, data}) do
    with group when not is_nil(group) <- Map.get(data, mod),
      original when not is_nil(original) <- Map.get(group, prop),
      current = original - amount
    do
      {{:prop_changed, id, %{mod => %{prop => current}}}, %{mod => %{group | prop => current}}}
    else
      _ -> {[], %{}}
    end
  end

  def resolve({:lost, prop, amount}, {id, _context, %{currencies: currencies, points: points}}) do
    if Map.has_key?(currencies, prop) do
      current = Map.get(currencies, prop) - amount
      {{:prop_changed, id, %{prop => current}}, %{currencies: %{currencies | prop => current}}}
    else
      if Map.has_key?(points, prop) do
        current = Map.get(points, prop) - amount
        {{:prop_changed, id, %{prop => current}}, %{points: %{points | prop => current}}}
      end
    end
  end

  def resolve({:gainExpSpeed, times, sec}, {id, _context, _data}) do
    new_speed = %{speed: times, sec: sec}
    {{:prop_changed, id, new_speed}, %{gainExpSpeed: new_speed}}
  end

  def resolve({:onHookTime, times}, {id, _context, %{onHookTime: onHookTime}}) do
    cur_times = onHookTime + times
    {{:prop_changed, id, %{onHookTime: min(cur_times, 20)}}, %{onHookTime: min(cur_times, 20)}}
  end

  def resolve({:bagCells, num}, {id, _context, %{bagCells: bagCells}}) do
    new_bagCells = bagCells + num
    {{:prop_changed, id, %{bagCells: new_bagCells}}, %{bagCells: new_bagCells}}
  end

  def resolve({:vip, lv, sec}, {id, _context, %{vip: vip}}) do
    new_vip = %{vip | level: lv, sec: sec}
    {{:prop_changed, id, %{vip: new_vip}}, %{vip: new_vip}}
  end

  def resolve(effect, {_id, _context, _data}) do
    IO.puts "unknown effect #{inspect effect}"

    {[], %{}}
  end

end
