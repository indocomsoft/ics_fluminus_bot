defmodule IcsFluminusBot.Worker do
  @moduledoc """
  The GenServer in charge of polling announcement of different modules.

  The state is {{username, password}, iso8601_last_fetched}
  """

  # 1 minute
  @interval 1 * 60 * 1000

  @base_dir Application.get_env(:ics_fluminus_bot, :state_base_dir)
  @last_fetched_file Path.join(@base_dir, "state.dat")

  @authorized_id Application.get_env(:ics_fluminus_bot, :id)

  @message_max_length 4096

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

    last_fetched =
      case File.read(@last_fetched_file) do
        {:ok, content} ->
          {:ok, datetime, _} = content |> String.trim() |> DateTime.from_iso8601()
          datetime

        {:error, reason} ->
          Logger.error("Unable to open file: #{reason}. Using unix epoch as the last_fetched.")
          DateTime.from_unix!(0)
      end

    Logger.info("Successfully initialized #{__MODULE__} with last_fetched #{last_fetched}")

    Logger.info("Scheduling next fetch in #{div(@interval, 1000)}s")
    Process.send_after(self(), :fetch, @interval)

    {:ok, {{username, password}, last_fetched}}
  end

  @impl true
  def handle_info(:fetch, {credential = {username, password}, last_fetched}) do
    Logger.info("Fetching announcements")

    try do
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

            message
            |> split_message()
            |> Enum.each(fn msg ->
              ExGram.send_message(@authorized_id, msg, parse_mode: "markdown")
            end)

            if DateTime.compare(datetime, acc) == :gt, do: datetime, else: acc
          end)
        end)

      new_last_fetched_iso8601 = DateTime.to_iso8601(new_last_fetched)
      File.write!(@last_fetched_file, new_last_fetched_iso8601)

      Logger.info(
        "Scheduling next fetch in #{div(@interval, 1000)}s, new_last_fetched = #{
          new_last_fetched_iso8601
        }"
      )

      Process.send_after(self(), :fetch, @interval)

      {:noreply, {credential, new_last_fetched}}
    rescue
      error ->
        Logger.error("Unable to fetch announcement, error = #{error}")
        {:noreply, {credential, last_fetched}}
    end
  end

  defp split_message(message) when is_binary(message) do
    length = String.length(message)

    if length > @message_max_length do
      chunk_len = chunk_length(length)
      num_chunks = div(length - 1, chunk_len) + 1

      message
      |> String.graphemes()
      |> Enum.chunk_every(chunk_len)
      |> Enum.with_index()
      |> Enum.map(fn {chunk, i} ->
        Enum.join(chunk) <> "\n(#{i + 1}/#{num_chunks})"
      end)
    else
      [message]
    end
  end

  defp chunk_length(length), do: chunk_length(length, Enum.min([length, @message_max_length]))

  defp chunk_length(length, result) do
    num_chunks = div(length - 1, result) + 1
    # 8 for each of \n, (, ), / with 4 buffer
    if result + 8 + String.length("#{num_chunks}") <= @message_max_length do
      result
    else
      chunk_length(length, result - 1)
    end
  end

  # Client functionality

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
end
