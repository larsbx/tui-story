defmodule SemanticGraph.Repo do
  @moduledoc """
  The Ecto repository backing every Ash resource in this application.

  The graph lived in `Ash.DataLayer.Ets` until now, which meant it did not
  survive a restart. Vertices and edges are ordinary rows here, and the edge
  table carries the uniqueness the deduplication rule used to enforce by
  reading before writing.
  """

  use AshPostgres.Repo, otp_app: :semantic_graph

  @impl true
  def installed_extensions do
    # ash-functions supplies the helpers Ash generates into migrations.
    ["ash-functions"]
  end

  @impl true
  def min_pg_version do
    %Version{major: 14, minor: 0, patch: 0}
  end
end
