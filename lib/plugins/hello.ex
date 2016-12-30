defmodule Fitbot.Plugin.Hello do
  alias Experimental.GenStage
  use GenStage
  require Logger

  def start_link() do
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    # Add identifying data to logger output
    Logger.configure_backend :console, metadata: [:plugin]
    Logger.metadata(plugin: __MODULE__)
    {:consumer, :ok, subscribe_to: [{Fitbot.Dispatcher, selector: fn %{command: command} -> command == :hello end}]}
  end

  def handle_events(events, _from, state) do
    Logger.debug "Received events: #{inspect(events)}"
    for event <- events do
      process(event)
    end
    {:noreply, [], state}
  end

  defp process(%{client: client, channel: channel, sender: %{nick: nick}, args: args}) when length(args) > 0 do
    ExIrc.Client.msg client, :privmsg, channel || nick, "Hello #{Enum.join(args, " ")}!"
  end
  defp process(%{client: client, channel: channel, sender: %{nick: nick}}) do
    ExIrc.Client.msg client, :privmsg, channel || nick, "Hello #{nick}!"
  end
end
