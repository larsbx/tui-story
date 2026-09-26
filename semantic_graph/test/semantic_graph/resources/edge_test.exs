defmodule SemanticGraph.Resources.EdgeTest do
  use SemanticGraph.DataCase, async: true

  alias SemanticGraph.Resources.{Vertex, Edge}

  setup do
    {:ok, v1} = Vertex.add_idea(%{content: "Concept A"})
    {:ok, v2} = Vertex.add_idea(%{content: "Concept B"})
    {:ok, v3} = Vertex.add_idea(%{content: "Concept C"})

    %{v1: v1, v2: v2, v3: v3}
  end

  describe "add_relationship/1" do
    test "creates edge with valid attributes", %{v1: v1, v2: v2} do
      {:ok, edge} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :analogous,
        certainty: 0.85,
        description: "Similar concepts"
      })

      assert edge.from_vertex_id == v1.id
      assert edge.to_vertex_id == v2.id
      assert edge.relation_type == :analogous
      assert edge.certainty == 0.85
      assert edge.description == "Similar concepts"
    end

    test "creates edge with default certainty", %{v1: v1, v2: v2} do
      {:ok, edge} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :implicative
      })

      assert edge.certainty == 0.5
    end

    test "rejects edge without required fields", %{v1: v1} do
      assert {:error, _} = Edge.add_relationship(%{
        from_vertex_id: v1.id
        # Missing to_vertex_id and relation_type
      })
    end

    test "rejects self-loops", %{v1: v1} do
      assert {:error, _} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v1.id,
        relation_type: :analogous
      })
    end

    test "rejects invalid relation type", %{v1: v1, v2: v2} do
      assert {:error, _} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :invalid_type
      })
    end
  end

  describe "database constraints" do
    # The deduplication rule and the self-loop rule are claims about what the
    # graph can contain, so they are tested against the database directly.
    # Going through the Ash action would only show the action checks them; these
    # inserts bypass it entirely, which is the difference between an illegal
    # state being rejected and being unrepresentable.

    test "a duplicate relationship cannot be inserted", %{v1: v1, v2: v2} do
      {:ok, _} =
        Edge.add_relationship(%{
          from_vertex_id: v1.id,
          to_vertex_id: v2.id,
          relation_type: :analogous,
          certainty: 0.9
        })

      assert_raise Postgrex.Error, ~r/edges_unique_relationship_index/, fn ->
        insert_edge_directly(v1.id, v2.id, "analogous")
      end
    end

    test "a self-loop cannot be inserted", %{v1: v1} do
      assert_raise Postgrex.Error, ~r/edges_no_self_loops/, fn ->
        insert_edge_directly(v1.id, v1.id, "analogous")
      end
    end
  end

  defp insert_edge_directly(from_id, to_id, relation_type) do
    SemanticGraph.Repo.query!(
      """
      INSERT INTO edges
        (id, from_vertex_id, to_vertex_id, relation_type, certainty, inserted_at, updated_at)
      VALUES (gen_random_uuid(), $1, $2, $3, 0.1, now(), now())
      """,
      [Ecto.UUID.dump!(from_id), Ecto.UUID.dump!(to_id), relation_type]
    )
  end

  describe "certainty-based deduplication" do
    test "skips duplicate with lower certainty", %{v1: v1, v2: v2} do
      # Create initial edge with high certainty
      {:ok, edge1} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :analogous,
        certainty: 0.9
      })

      # Try to add duplicate with lower certainty
      result = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :analogous,
        certainty: 0.5
      })

      assert {:error, _} = result

      # Verify only one edge exists
      edges = Edge.list_all!()
      matching = Enum.filter(edges, fn e ->
        e.from_vertex_id == v1.id and
        e.to_vertex_id == v2.id and
        e.relation_type == :analogous
      end)

      assert length(matching) == 1
      assert hd(matching).certainty == 0.9
    end

    test "updates edge with higher certainty", %{v1: v1, v2: v2} do
      # Create initial edge with low certainty
      {:ok, edge1} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :implicative,
        certainty: 0.5,
        description: "Initial"
      })

      # Add duplicate with higher certainty
      result = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :implicative,
        certainty: 0.9,
        description: "Updated"
      })

      # The upsert updates in place and returns the edge. It used to signal
      # "updated" by returning an error, which the caller could not tell apart
      # from a real failure.
      assert {:ok, updated} = result
      assert updated.certainty == 0.9

      # Verify edge was updated
      edges = Edge.list_all!()
      matching = Enum.filter(edges, fn e ->
        e.from_vertex_id == v1.id and
        e.to_vertex_id == v2.id and
        e.relation_type == :implicative
      end)

      assert length(matching) == 1
      edge = hd(matching)
      assert edge.certainty == 0.9
      assert edge.description == "Updated"
    end

    test "allows different relationship types between same vertices", %{v1: v1, v2: v2} do
      {:ok, edge1} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :analogous,
        certainty: 0.8
      })

      {:ok, edge2} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :causal,
        certainty: 0.7
      })

      assert edge1.id != edge2.id
      assert edge1.relation_type == :analogous
      assert edge2.relation_type == :causal
    end
  end

  describe "update_certainty/2" do
    test "updates certainty value", %{v1: v1, v2: v2} do
      {:ok, edge} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :analogous,
        certainty: 0.5
      })

      {:ok, updated} = Edge.update_certainty(edge, %{certainty: 0.9})
      assert updated.certainty == 0.9
    end

    test "rejects invalid certainty", %{v1: v1, v2: v2} do
      {:ok, edge} = Edge.add_relationship(%{
        from_vertex_id: v1.id,
        to_vertex_id: v2.id,
        relation_type: :analogous
      })

      assert {:error, _} = Edge.update_certainty(edge, %{certainty: 1.5})
      assert {:error, _} = Edge.update_certainty(edge, %{certainty: -0.1})
    end
  end

  describe "relation_symbol/1" do
    test "returns correct symbols for all relation types" do
      assert Edge.relation_symbol(:contradictory) == "⊥"
      assert Edge.relation_symbol(:implicative) == "→"
      assert Edge.relation_symbol(:hierarchical) == "⊆"
      assert Edge.relation_symbol(:evolutionary) == "⟿"
      assert Edge.relation_symbol(:analogous) == "≈"
      assert Edge.relation_symbol(:synonymous) == "≡"
      assert Edge.relation_symbol(:antonymous) == "≠"
      assert Edge.relation_symbol(:part_whole) == "∈"
      assert Edge.relation_symbol(:causal) == "⇒"
    end
  end
end
