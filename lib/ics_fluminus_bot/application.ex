defmodule IcsFluminusBot.Application do
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    token = ExGram.Config.get(:ex_gram, :token)

    children = [
      ExGram,
      {IcsFluminusBot, [method: :polling, token: token]},
      IcsFluminusBot.Worker
    ]

    opts = [strategy: :one_for_one, name: IcsFluminusBot.Supervisor]

    Logger.info("Starting IcsFluminusBot supervisor")

    Supervisor.start_link(children, opts)
  end
end
