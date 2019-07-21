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

end
