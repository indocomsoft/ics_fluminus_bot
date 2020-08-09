defmodule IcsFluminusBot.Worker do
  @moduledoc """
  The GenServer in charge of polling announcement of different modules.

  The state is {{username, password}, unix_time_last_fetched}
  """

  # 1 minute
  @interval 1 * 60 * 1000

  @last_fetched_file "state.dat"

  @authorized_id Application.get_env(:ics_fluminus_bot, :id)

  use GenServer

  require Logger

  alias Fluminus.API
  alias Fluminus.API.Module
  alias Fluminus.Authorization

  # Server functionality

  @impl true
  def init(_) do
    Logger.info("Worker: initializing")

    %{username: username, password: password} =
      Application.get_env(:ics_fluminus_bot, :credential)

    {:ok, %Authorization{}} = Authorization.vafs_jwt(username, password)

    last_fetched =
      case File.read("./#{@last_fetched_file}") do
        {:ok, content} ->
          content |> String.trim() |> String.to_integer()

        {:error, reason} ->
          Logger.error("Unable to open file: #{reason}. Using 0 as the last_fetched_unix_time.")
          0
      end

    Logger.info(
      "Successfully initialized #{__MODULE__} with last_fetched #{last_fetched} = #{
        last_fetched |> DateTime.from_unix!() |> DateTime.to_iso8601()
      }"
    )

    Logger.info("Scheduling next fetch in #{div(@interval, 1000)}s")
    Process.send_after(self(), :fetch, @interval)

    {:ok, {{username, password}, last_fetched}}
  end

  @impl true
  def handle_info(:fetch, {credential = {username, password}, last_fetched_unix}) do
    Logger.info("Fetching announcements")

    last_fetched = DateTime.from_unix!(last_fetched_unix)

    {:ok, auth = %Authorization{}} = Authorization.vafs_jwt(username, password)
    {:ok, modules} = API.modules(auth, true)

    new_last_fetched =
      Enum.reduce(modules, last_fetched, fn module = %Module{code: code, name: name}, acc ->
        {:ok, announcements} = Module.announcements(module, auth)

        announcements
        |> Enum.filter(fn %{datetime: datetime} ->
          DateTime.compare(datetime, last_fetched) == :gt
        end)
        |> Enum.reduce(acc, fn %{title: title, description: description, datetime: datetime},
                               acc ->
          datetime_formatted =
            datetime
            |> DateTime.shift_zone!("Asia/Singapore")
            |> NimbleStrftime.format("%d %b %Y, %H:%M:%S")

          message =
            "*#{code} - #{name}*\n*#{title}*\n#{datetime_formatted}\n#{String.trim(description)}"

          Logger.info("New announcement in #{code}, datetime = #{datetime_formatted}")
          ExGram.send_message(@authorized_id, message, parse_mode: "markdown")

          if DateTime.compare(datetime, acc) == :gt, do: datetime, else: acc
        end)
      end)

    Logger.info("Scheduling next fetch in #{div(@interval, 1000)}s")
    Process.send_after(self(), :fetch, @interval)

    new_last_fetched_unix = DateTime.to_unix(new_last_fetched)
    File.write!("./#{@last_fetched_file}", Integer.to_string(new_last_fetched_unix))

    {:noreply, {credential, new_last_fetched_unix}}
  end

  # Client functionality

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
end
