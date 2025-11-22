defmodule SemanticGraph.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      SemanticGraphWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: SemanticGraph.PubSub},
      # Start Finch
      {Finch, name: SemanticGraph.Finch},
      # Start Graphiti integration (Phase 3)
      {SemanticGraph.Graphiti.Integration, []},
      # Start the Phoenix Endpoint (optional for web interface)
      # SemanticGraphWeb.Endpoint,
      # Start Ratatouille TUI (Phase 4 - Complete)
      {Ratatouille.Runtime.Supervisor,
        runtime: [
          app: SemanticGraph.TUI,
          shutdown: {:application, :semantic_graph},
          quit_events: [
            {:key, Ratatouille.Constants.key(:ctrl_c)},
            {:key, Ratatouille.Constants.key(:ctrl_d)}
          ]
        ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SemanticGraph.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SemanticGraphWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
