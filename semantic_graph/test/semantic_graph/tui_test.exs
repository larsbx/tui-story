defmodule SemanticGraph.TUITest do
  use SemanticGraph.DataCase, async: false

  alias SemanticGraph.GraphAPI
  alias SemanticGraph.Resources.{Edge, Vertex}
  alias SemanticGraph.TUI
  alias SemanticGraph.TUI.State

  setup do
    {:ok, first} = Vertex.add_idea(%{content: "First"})
    {:ok, second} = Vertex.add_idea(%{content: "Second"})

    {:ok, edge} =
      Edge.add_relationship(%{
        from_vertex_id: first.id,
        to_vertex_id: second.id,
        relation_type: :analogous,
        certainty: 0.8
      })

    state = %State{
      mode: :help,
      ideas: [first.content, second.content],
      graph: %{vertices: [first, second], edges: [edge]}
    }

    %{state: state}
  end

  describe "reset flow" do
    test "pressing r asks for confirmation without deleting data", %{state: state} do
      updated = TUI.update(state, {:event, %{ch: ?r}})

      assert updated.mode == :confirming_reset
      assert length(Vertex.list_all!()) == 2
      assert length(Edge.list_all!()) == 1
    end

    test "n cancels reset and preserves the graph", %{state: state} do
      confirming = TUI.update(state, {:event, %{ch: ?r}})
      updated = TUI.update(confirming, {:event, %{ch: ?n}})

      assert updated.mode == :help
      assert length(Vertex.list_all!()) == 2
      assert length(Edge.list_all!()) == 1
    end

    test "escape cancels reset and preserves the graph", %{state: state} do
      confirming = TUI.update(state, {:event, %{ch: ?r}})
      escape = Ratatouille.Constants.key(:esc)
      updated = TUI.update(confirming, {:event, %{key: escape}})

      assert updated.mode == :help
      assert length(Vertex.list_all!()) == 2
      assert length(Edge.list_all!()) == 1
    end

    test "y delegates to the domain reset and leaves a reusable empty graph", %{state: state} do
      confirming = TUI.update(state, {:event, %{ch: ?r}})
      updated = TUI.update(confirming, {:event, %{ch: ?y}})

      assert updated.mode == :help
      assert updated.ideas == []
      assert updated.graph == nil
      assert Vertex.list_all!() == []
      assert Edge.list_all!() == []

      assert {:ok, vertex} = Vertex.add_idea(%{content: "After reset"})
      assert vertex.content == "After reset"
      assert GraphAPI.get_graph_state().vertex_count == 1
    end
  end
end
