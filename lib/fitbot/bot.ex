defmodule Fitbot.Bot do
  use GenServer
  require Logger

  alias ExIrc.Client
  alias ExIrc.SenderInfo

  alias Fitbot.Dispatcher

  defmodule Config do
    defstruct [:server, :port, :pass, :nick, :user, :name, :channels, :client]

    def from_params(params) when is_map(params) do
      Enum.reduce(params, %Config{}, fn {k, v}, acc ->
        case Map.has_key?(acc, k) do
          true -> Map.put(acc, k, v)
          false -> acc
        end
      end)
    end
  end

  def start_link(%{identifier: identifier} = params) when is_map(params) do
    config = Config.from_params(params)
    GenServer.start_link(__MODULE__, [config], name: String.to_atom(identifier))
  end

  def get_client(bot, timeout \\ 5000) do
    GenServer.call(bot, {:get, :client}, timeout)
  end

  # ------

  def init([config]) do

    # Print data about which bot we're talking about when logging
    Logger.configure_backend :console, metadata: [:server, :nick]
    Logger.metadata(server: config.server, nick: config.nick)

    {:ok, client} = ExIrc.start_client!

    Client.add_handler(client, self)

    Logger.debug "Connecting..."
    Client.connect! client, config.server, config.port

    {:ok, %Config{config | client: client}}
  end

  def handle_call({:get, :client}, _from, config) do
    {:reply, config.client, config}
  end

  def handle_info({:connected, _server, _port}, config) do
    Logger.debug "Connected!"
    Logger.debug "Logging in as #{config.nick}..."
    Client.logon config.client, config.pass, config.nick, config.user, config.name
    {:noreply, config}
  end

  def handle_info(:logged_in, config) do
    Logger.debug "Logged in!"
    Enum.map config.channels, fn channel ->
      Logger.debug "Joining #{channel}.."
      Client.join config.client, channel
    end
    {:noreply, config}
  end

  def handle_info(:disconnected, config) do
    Logger.debug "Disconnected"
    {:stop, :normal, config}
  end

  def handle_info({:joined, channel}, config) do
    Logger.debug "Joined #{channel}"
    {:noreply, config}
  end

  def handle_info({:mentioned, _msg, %SenderInfo{}, channel}, config) do
    Client.msg config.client, :privmsg, channel, "Talk to the hand"
    {:noreply, config}
  end

  def handle_info({:received, "!" <> msg, %SenderInfo{} = sender, channel}, config) do
    dispatch_command config.client, sender, channel, String.split(msg, " ")
    {:noreply, config}
  end

  def handle_info({:received, "!" <> msg, %SenderInfo{} = sender}, config) do
    dispatch_command config.client, sender, nil, String.split(msg, " ")
    {:noreply, config}
  end

  def handle_info(_msg, config) do
    {:noreply, config}
  end

  def terminate(_reason, state) do
    Client.quit state.client
    Client.stop! state.client
    :ok
  end

  defp dispatch_command(client, sender, channel, [command | args]) do
    Dispatcher.notify %{
                         client: client,
                         sender: sender,
                         channel: channel,
                         command: String.to_atom(command),
                         args: args
                       }
  end
end
