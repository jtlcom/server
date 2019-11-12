defmodule Periods.ThirtyDays.AvatarStruct do
  defstruct last_update_time: 0,
            # 参与活动时间
            acc_days_num: 0,
            # 累积登陆天数
            is_today_count: false,
            # 今日是否已登陆
            last_refresh_time: 0,
            # 最近一次刷新次数时间
            received_award_id: []

  # 已经领取了的奖励的活动id
end

defmodule Periods.ThirtyDays do
  alias Periods.ThirtyDays.AvatarStruct
  require Logger

  defp init_act_data(now_time) do
    %AvatarStruct{%AvatarStruct{} | last_update_time: now_time, last_refresh_time: now_time}
  end

  defp avatar_act_data(act_id, periods) do
    case periods |> Map.get(act_id) do
      nil ->
        init_act_data(Utils.timestamp())

      act_data ->
        Map.merge(%AvatarStruct{}, act_data)
    end
  end

  defp update_periods(periods, act_id, act_data) do
    periods |> Map.put(act_id, Map.from_struct(act_data))
  end

  def check_reset(act_id, now_time, {_aid, %{periods: periods} = data}) do
    case avatar_act_data(act_id, periods) do
      %AvatarStruct{
        last_refresh_time: last_refresh_time,
        acc_days_num: acc_days_num,
        is_today_count: is_today_count
      } = act_data ->
        act_data =
          if Utils.diff_days(last_refresh_time, now_time, true) != 0 or not is_today_count do
            %AvatarStruct{
              act_data
              | last_refresh_time: now_time,
                is_today_count: true,
                acc_days_num: acc_days_num + 1
            }
          else
            act_data
          end

        periods = update_periods(periods, act_id, act_data)
        data |> Map.put(:periods, periods)

      _ ->
        data
    end
  end
end
