defmodule Item do
  @items_table :items

  def init() do
    :dets.open_file(@items_table, [])
    initgoods() 
  end

  #仅仅初始化了与bag中sell，buy，bag2warehouse，warehouse2bag函数相关的信息
  #若想调用bag中的use，则还要新添加相应的物品信息
  #如：经验丹
  #defp declare(:exp, %{consume: consume?, params: [exp]}, {index, _item, count}, _gene) do
  #需要添加的物品的信息可以是：
  #将item_id=5的物品改为经验丹 每个增加经验1000
  #Item.insert({5,%{:sell => %{:bindGold=>5, :coin => 5, :gold => 5}, :buy => %{:bindGold=>5, :coin => 5, :gold => 5}, :stack => 100000, :require => [], :actions => %{:exp => %{consume: true, params: [1000]}}}})
  #上面主要添加了:require和:actions
  def initgoods() do
    goodids=[1,2,3,4,5,6,201,202,203,301,401,501,802,810]
    for goodid <- goodids
    do
      Item.insert({goodid,%{:sell => %{:bindGold=>goodid, :coin => goodid, :gold => goodid}, :buy => %{:bindGold=>goodid, :coin => goodid, :gold => goodid}, :stack => 100000}})
    end
  end

  def insert(item) do
    :dets.insert(@items_table, item)
  end

  def get(item_id) do
    case :dets.match(@items_table, {item_id, :'$1'}) do
      [[attributes]] -> attributes
      _ -> nil
    end
  end


  def get_object(item_id) do
    case :dets.match_object(@items_table, {item_id, :'$1'}) do
      [{item_id,attributes}] -> attributes
      _ -> nil
    end
  end

  def getfirst() do
    :dets.first(@items_table)
  end

  def getinfo() do
    :dets.info(@items_table)
  end

  def delitem(item_id) do
    :dets.delete(@items_table,item_id)
  end


  def close() do
    :dets.close(@items_table)
  end

end
#{item_id, attributes}
