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
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "edges"
    repo SemanticGraph.Repo

    references do
      reference :from_vertex, on_delete: :delete
      reference :to_vertex, on_delete: :delete
    end

    check_constraints do
      check_constraint :to_vertex_id, "edges_no_self_loops",
        check: "from_vertex_id != to_vertex_id",
        message: "Self-loops are not allowed"
    end
  end

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

      # Deduplication by certainty, as one statement instead of a read followed
      # by a write. The previous version queried for an existing edge inside a
      # change function and then decided -- two round trips with a window
      # between them, so two concurrent analyses of the same pair could both see
      # "no existing edge" and both insert. The :unique_relationship identity
      # makes that second row impossible rather than merely unlikely, and the
      # condition below becomes the ON CONFLICT ... WHERE clause:
      #
      #   no existing edge                     -> insert
      #   existing.certainty < incoming        -> update certainty and description
      #   existing.certainty >= incoming       -> Ash.Error.Changes.StaleRecord
      #
      # Inside upsert_condition a bare field is the stored value and
      # upsert_conflict/1 is the incoming one.
      upsert? true
      upsert_identity :unique_relationship
      upsert_fields [:certainty, :description]
      upsert_condition expr(certainty < upsert_conflict(:certainty))
    end

    update :update_certainty do
      accept [:certainty, :description]

      validate numericality(:certainty,
                 greater_than_or_equal_to: 0.0,
                 less_than_or_equal_to: 1.0
               )
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

  identities do
    # One edge per (from, to, type). The deduplication rule above is expressed
    # against this identity, and Postgres holds the unique index that makes a
    # duplicate unrepresentable rather than rejected after the fact.
    identity :unique_relationship, [:from_vertex_id, :to_vertex_id, :relation_type]
  end

  validations do
    # Only :create sets the endpoints -- update_certainty accepts
    # [:certainty, :description] and update_description accepts [:description],
    # so neither can introduce a self-loop. Running this on them would cost
    # those actions their atomicity for a check that cannot fire. The database
    # check constraint above is the guarantee; this is the readable message.
    validate fn changeset, _context ->
                 from_id = Ash.Changeset.get_attribute(changeset, :from_vertex_id)
                 to_id = Ash.Changeset.get_attribute(changeset, :to_vertex_id)

                 if from_id && to_id && from_id == to_id do
                   {:error, field: :to_vertex_id, message: "Self-loops are not allowed"}
                 else
                   :ok
                 end
               end,
               on: [:create]
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
