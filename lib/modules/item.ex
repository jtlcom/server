defmodule Item do
  @items_table :items

  def init() do
    :dets.open_file(@items_table, [])
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

  def close() do
    :dets.close(@items_table)
  end
  
end
#{item_id, attributes}