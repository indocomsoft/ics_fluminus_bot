import Config

config :logger,
  backends: [:console],
  level: :info,
  compile_time_purge_matching: [[level_lower_than: :info]]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ics_fluminus_bot, name: :ics_fluminus_bot

import_config "secrets.exs"
