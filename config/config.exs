use Mix.Config

config :ssss_server, server_id: 1
config :ssss_server, port: 3256

config :ssss_server, config_base_url: "http://192.168.1.170:5984/ssss_config/"

# config :ssss_server, redis_url: "redis://192.168.1.170:6379/13"

# disable tzdata auto update
config :tzdata, autoupdate: :disabled

config :timex, local_timezone: "Asia/Shanghai"

config :logger, :console, format: "<=====$time $metadata[$level] ======>\n\n $levelpad$message\n\n",
  metadata: [:module, :function, :line], level: :debug

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
