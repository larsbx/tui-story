defmodule SemanticGraphWeb.HealthController do
  use SemanticGraphWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      status: "healthy",
      service: "semantic-graph",
      version: "0.1.0",
      timestamp: DateTime.utc_now()
    })
  end
end
