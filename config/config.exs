import Config

config :logger,
  backends: [:console],
  level: :info,
  compile_time_purge_matching: [[level_lower_than: :info]]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :ics_fluminus_bot, name: :ics_fluminus_bot

token = System.get_env("TOKEN")

case token do
  nil ->
    import_config "secrets.exs"

  x when is_binary(x) ->
    config :ex_gram, token: token

    id =
      System.get_env("ID") |> String.to_integer() ||
        raise """
        environment variable ID is missing.
        """

    username =
      System.get_env("USERNAME") ||
        raise """
        environment variable USERNAME is missing.
        """

    password =
      System.get_env("PASSWORD") ||
        raise """
        environment variable PASSWORD is missing.
        """

    config :ics_fluminus_bot, id: id, credential: %{username: username, password: password}
end
