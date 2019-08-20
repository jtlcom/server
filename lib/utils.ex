defmodule Utils do
  defmacro to_atom(string) do
    if Mix.env == :dev do
      quote do: String.to_atom(unquote(string))
    else
      quote do: String.to_existing_atom(unquote(string))
    end
  end

  defmacro ensure_module(mod) do
    if Mix.env == :dev do
      quote do: Code.ensure_loaded(unquote(mod))
    end
  end

  def to_tuple(list) when is_list(list) do
    List.to_tuple(list)
  end

  def to_tuple(tuple) when is_tuple(tuple) do
    tuple
  end

    #---------------------------------------------------------------------
  # UTC时间戳(秒)
  # @local_zone Timex.local().time_zone
  def timestamp() do
    System.system_time(:second)
  end

    # 时间戳转时间
    def timestamp_to_datetime(time_stamp) do
      Timex.to_datetime(Timex.from_unix(time_stamp), Timex.local().time_zone)
    end

  def diff_days(t1, t2, by_zero \\ false) do
    datetime1 = by_zero && Timex.beginning_of_day(timestamp_to_datetime(t1)) || timestamp_to_datetime(t1)
    datetime2 = by_zero && Timex.beginning_of_day(timestamp_to_datetime(t2)) || timestamp_to_datetime(t2)
    (t1 >= t2) && Timex.diff(datetime1, datetime2, :days) || Timex.diff(datetime2, datetime1, :days)
  end

end
