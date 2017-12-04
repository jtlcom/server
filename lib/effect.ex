defmodule Effect do

  def from_cost(cost) when is_tuple(cost) do
    List.wrap(cost) |> from_cost
  end

  def from_cost(cost) do
    cost |> Enum.map(fn
      {:item, id, count} -> {:lost, {:item, id}, count}
      {{:bag, index}, count} -> {:lost, {:bag, index}, count}
      {point, amount} -> {:lost, point, amount}
    end)
  end

  def from_rewards(rewards) when is_tuple(rewards) do
    List.wrap(rewards) |> from_rewards
  end

  def from_rewards(rewards) do
    rewards |> Enum.map(fn
      {:item, id, count} -> {:gain, {:item, id}, count}
      {point, amount} -> {:gain, point, amount}
    end)
  end

  def from_cost_rewards(cost, rewards) do
    Enum.concat from_cost(cost), from_rewards(rewards)
  end
end
