defmodule IcsFluminusBot do
  @moduledoc """
  Documentation for IcsFluminusBot
  """

  @help_message """
  `/start` to get the welcome message and status of the bot
  `/help` to get help message
  """

  @authorized_id Application.get_env(:ics_fluminus_bot, :id)

  use ExGram.Bot, name: Application.get_env(:ics_fluminus_bot, :name)

  require Logger

  command "start"
  command "help"

  def handle({:command, :help, %{}}, cnt) do
    answer(cnt, @help_message, parse_mode: "markdown")
  end

  def handle({:command, :start, %{from: %{id: @authorized_id, first_name: first_name}}}, cnt) do
    status =
      with %{username: username, password: password}
           when is_binary(username) and is_binary(password) <-
             Application.get_env(:ics_fluminus_bot, :credential),
           {:ok, %Fluminus.Authorization{}} <- Fluminus.Authorization.vafs_jwt(username, password) do
        "You're all set up with username #{username}"
      else
        {:error, :invalid_credentials} -> "Your credential in secrets.exs is invalid"
        _ -> "Missing credentia in secrets.exs"
      end

    answer(cnt, "Welcome to ICS Fluminus Bot, #{first_name}! #{status}")
  end

  def handle({:command, :start, %{}}, cnt) do
    answer(
      cnt,
      "You're not an authorized user. Create your own fork from https://github.com/indocomsoft/ics_fluminus_bot"
    )
  end
end
