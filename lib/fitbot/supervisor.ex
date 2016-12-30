defmodule Fitbot.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    bots = Application.get_env(:fitbot, :bots)
           |> Enum.map(fn bot -> worker(Fitbot.Bot, [bot]) end)

    plugins = Application.get_env(:fitbot, :plugins)
              |> Enum.map(fn plugin -> worker(plugin, []) end)

    children = [
        worker(Fitbot.Dispatcher, [])
    ] ++ bots ++ plugins

    supervise(children, strategy: :one_for_one)
  end
end
