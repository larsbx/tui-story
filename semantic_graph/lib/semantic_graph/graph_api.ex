defmodule SemanticGraph.GraphAPI do
  @moduledoc """
  The SemanticGraph Ash Domain (API).

  This domain provides a unified interface for all graph operations,
  coordinating between Vertex and Edge resources.

  ## Resources

  - `SemanticGraph.Resources.Vertex` - Ideas/concepts in the graph
  - `SemanticGraph.Resources.Edge` - Semantic relationships between ideas

  ## Usage

  ```elixir
  # Add a new idea
  {:ok, vertex} = SemanticGraph.GraphAPI.Vertex.add_idea(%{content: "Machine learning"})

  # Create a relationship
  {:ok, edge} = SemanticGraph.GraphAPI.Edge.add_relationship(%{
    from_vertex_id: vertex1.id,
    to_vertex_id: vertex2.id,
    relation_type: :analogous,
    certainty: 0.85
  })

  # Query all vertices
  vertices = SemanticGraph.GraphAPI.Vertex.list_all!()

  # Query all edges
  edges = SemanticGraph.GraphAPI.Edge.list_all!()
  ```
  """

  use Ash.Domain

  resources do
    resource SemanticGraph.Resources.Vertex do
      # Define any domain-specific customizations here
    end

    resource SemanticGraph.Resources.Edge do
      # Define any domain-specific customizations here
    end
  end

  @doc """
  Get the complete graph state.

  Returns a map with all vertices and edges.
  """
  def get_graph_state do
    vertices = SemanticGraph.Resources.Vertex
    |> Ash.read!(authorize?: false)

    edges = SemanticGraph.Resources.Edge
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:from_vertex, :to_vertex], authorize?: false)

    %{
      vertices: vertices,
      edges: edges,
      vertex_count: length(vertices),
      edge_count: length(edges)
    }
  end

  @doc """
  Get edges for a specific vertex.

  Returns both incoming and outgoing edges.
  """
  def get_vertex_edges(vertex_id) do
    outgoing = SemanticGraph.Resources.Edge
    |> Ash.Query.filter(from_vertex_id == ^vertex_id)
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:to_vertex], authorize?: false)

    incoming = SemanticGraph.Resources.Edge
    |> Ash.Query.filter(to_vertex_id == ^vertex_id)
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:from_vertex], authorize?: false)

    %{
      outgoing: outgoing,
      incoming: incoming,
      total: length(outgoing) + length(incoming)
    }
  end

  @doc """
  Find vertices by content (case-insensitive partial match).
  """
  def search_vertices(query) do
    SemanticGraph.Resources.Vertex
    |> Ash.Query.filter(contains(content, ^query))
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Get edges by relationship type.
  """
  def get_edges_by_type(relation_type) do
    SemanticGraph.Resources.Edge
    |> Ash.Query.filter(relation_type == ^relation_type)
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:from_vertex, :to_vertex], authorize?: false)
  end

  @doc """
  Get edges with certainty above a threshold.
  """
  def get_high_certainty_edges(min_certainty \\ 0.8) do
    SemanticGraph.Resources.Edge
    |> Ash.Query.filter(certainty >= ^min_certainty)
    |> Ash.read!(authorize?: false)
    |> Ash.load!([:from_vertex, :to_vertex], authorize?: false)
  end

  @doc """
  Delete all data (reset graph).

  WARNING: This deletes all vertices and edges!
  """
  def reset_graph! do
    # Delete all edges first (due to foreign key constraints)
    SemanticGraph.Resources.Edge
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))

    # Delete all vertices
    SemanticGraph.Resources.Vertex
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))

    :ok
  end

  @doc """
  Get graph statistics.
  """
  def get_statistics do
    vertices = SemanticGraph.Resources.Vertex |> Ash.read!(authorize?: false)
    edges = SemanticGraph.Resources.Edge |> Ash.read!(authorize?: false)

    # Count edges by type
    edges_by_type = Enum.reduce(edges, %{}, fn edge, acc ->
      Map.update(acc, edge.relation_type, 1, &(&1 + 1))
    end)

    # Average certainty
    avg_certainty = if length(edges) > 0 do
      Enum.sum(Enum.map(edges, & &1.certainty)) / length(edges)
    else
      0.0
    end

    %{
      vertex_count: length(vertices),
      edge_count: length(edges),
      edges_by_type: edges_by_type,
      average_certainty: Float.round(avg_certainty, 2)
    }
  end
end
