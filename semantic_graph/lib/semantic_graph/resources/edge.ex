defmodule SemanticGraph.Resources.Edge do
  @moduledoc """
  Edge resource representing a semantic relationship between two vertices.

  Edges define the relationships in our knowledge graph. Each edge contains:
  - relation_type: The type of semantic relationship (9 types)
  - certainty: Confidence score (0.0 to 1.0)
  - description: Optional text description of the relationship
  - from_vertex_id, to_vertex_id: References to connected vertices

  The edge uses certainty-based update logic: if a duplicate relationship
  is added with higher certainty, it updates the existing edge rather than
  creating a new one.

  Ports functionality from src/graph.zig
  """

  use Ash.Resource,
    domain: SemanticGraph.GraphAPI,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "edge"
  end

  attributes do
    uuid_primary_key :id

    attribute :relation_type, :atom do
      allow_nil? false
      constraints one_of: [
        :contradictory,   # ⊥ - Ideas that contradict each other
        :implicative,     # → - One idea implies another
        :hierarchical,    # ⊆ - Parent-child or category relationship
        :evolutionary,    # ⟿ - One idea evolves into another
        :analogous,       # ≈ - Ideas are similar or analogous
        :synonymous,      # ≡ - Ideas mean essentially the same thing
        :antonymous,      # ≠ - Ideas are opposites
        :part_whole,      # ∈ - Part-of relationship
        :causal           # ⇒ - Cause and effect relationship
      ]
    end

    attribute :certainty, :float do
      default 0.5
      constraints min: 0.0, max: 1.0
    end

    attribute :description, :string do
      allow_nil? true
      constraints max_length: 500
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :from_vertex, SemanticGraph.Resources.Vertex do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :to_vertex, SemanticGraph.Resources.Vertex do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :add_relationship do
      accept [:from_vertex_id, :to_vertex_id, :relation_type, :certainty, :description]

      validate present([:from_vertex_id, :to_vertex_id, :relation_type])

      # Port logic from graph.zig:151-162 - update if higher certainty
      change fn changeset, _context ->
        from_id = Ash.Changeset.get_attribute(changeset, :from_vertex_id)
        to_id = Ash.Changeset.get_attribute(changeset, :to_vertex_id)
        rel_type = Ash.Changeset.get_attribute(changeset, :relation_type)
        new_certainty = Ash.Changeset.get_attribute(changeset, :certainty) || 0.5

        # Check for existing edge
        case find_existing_edge(from_id, to_id, rel_type) do
          nil ->
            # No duplicate, proceed with create
            changeset

          existing_edge ->
            if existing_edge.certainty < new_certainty do
              # Update existing edge with higher certainty
              new_description = Ash.Changeset.get_attribute(changeset, :description) ||
                                existing_edge.description

              case Ash.Changeset.for_update(
                existing_edge,
                :update_certainty,
                %{certainty: new_certainty, description: new_description}
              )
              |> Ash.update() do
                {:ok, _updated} ->
                  # Signal that we updated instead of created
                  Ash.Changeset.add_error(changeset,
                    field: :from_vertex_id,
                    message: "Updated existing edge with higher certainty",
                    vars: [edge_id: existing_edge.id]
                  )

                {:error, _} ->
                  # If update fails, proceed with create
                  changeset
              end
            else
              # Duplicate with equal/higher certainty, skip
              Ash.Changeset.add_error(changeset,
                field: :from_vertex_id,
                message: "Edge already exists with equal or higher certainty (#{existing_edge.certainty})"
              )
            end
        end
      end
    end

    update :update_certainty do
      accept [:certainty, :description]

      validate numeral_in_range(:certainty, 0.0..1.0)
    end

    update :update_description do
      accept [:description]
    end
  end

  code_interface do
    define :add_relationship, action: :add_relationship
    define :update_certainty, action: :update_certainty
    define :update_description, action: :update_description
    define :list_all, action: :read
    define :get_by_id, action: :read, get_by: [:id]
    define :destroy, action: :destroy
  end

  validations do
    validate fn changeset, _context ->
      from_id = Ash.Changeset.get_attribute(changeset, :from_vertex_id)
      to_id = Ash.Changeset.get_attribute(changeset, :to_vertex_id)

      if from_id && to_id && from_id == to_id do
        {:error, field: :to_vertex_id, message: "Self-loops are not allowed"}
      else
        :ok
      end
    end
  end

  # Helper function to find existing edge
  defp find_existing_edge(from_id, to_id, rel_type) do
    require Ash.Query

    SemanticGraph.Resources.Edge
    |> Ash.Query.filter(
      from_vertex_id == ^from_id and
      to_vertex_id == ^to_id and
      relation_type == ^rel_type
    )
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, edge} -> edge
      _ -> nil
    end
  end

  # Symbol mapping for display
  def relation_symbol(type) do
    case type do
      :contradictory -> "⊥"
      :implicative -> "→"
      :hierarchical -> "⊆"
      :evolutionary -> "⟿"
      :analogous -> "≈"
      :synonymous -> "≡"
      :antonymous -> "≠"
      :part_whole -> "∈"
      :causal -> "⇒"
    end
  end
end
