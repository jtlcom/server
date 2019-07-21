defmodule SsssServer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ssss_server,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Main, []},
      start_phases: [init: []]
    ]
  end

  defp deps do
    [{:ranch, "~> 1.4"},
     {:poison, "~> 3.1"},
     {:httpoison, "~> 0.13"},
     {:quantum, "~> 2.3"},
     {:timex, "~> 3.1"},
     {:redix, "~> 0.6"},
     {:logger_file_backend, "~> 0.0"},
     {:mongodb, "~> 0.4"},
     {:poolboy, "~> 1.5"},
     {:distillery, "~> 1.5"},
     {:cowboy, "~> 1.0"},
     {:plug, "~> 1.4"},
     {:changed_reloader, "~> 0.1.4"}]  #加入这个依赖后更改源代码后只需保存，iex中加载的模块会同步更新
  end
end
