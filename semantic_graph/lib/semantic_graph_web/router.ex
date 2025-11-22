defmodule SemanticGraphWeb.Router do
  use SemanticGraphWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", SemanticGraphWeb do
    pipe_through :api
  end

  # MCP Protocol endpoint (will be implemented in Phase 5)
  # scope "/", SemanticGraphWeb do
  #   post "/mcp", MCPController, :handle_request
  # end

  # Health check endpoint
  scope "/" do
    get "/health", SemanticGraphWeb.HealthController, :index
  end
end
