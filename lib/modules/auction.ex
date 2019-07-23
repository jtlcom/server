defmodule Auction do
  @auctions_table :auctions 

  def init() do
    :dets.open_file(@auctions_table, []) 
  end

  def insert(item) do
    :dets.insert(@auctions_table, item)
  end

  def delitem(item_id) do
    :dets.delete(@items_table,item_id)
  end

  def close() do
    :dets.close(@items_table)
  end

end