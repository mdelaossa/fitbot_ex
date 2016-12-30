defmodule Fitbot do
    use Application

    def start(_type, _args) do
      Fitbot.Supervisor.start_link
    end
end
