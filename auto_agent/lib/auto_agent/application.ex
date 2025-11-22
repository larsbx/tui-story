defmodule AutoAgent.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Start the Agent with a name so we can address it globally
      {AutoAgent.Server, name: AutoAgent.Server}
    ]

    opts = [strategy: :one_for_one, name: AutoAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
