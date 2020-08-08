import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ics_fluminus_bot, name: :ics_fluminus_bot

import_config "secrets.exs"
