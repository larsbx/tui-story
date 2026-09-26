defmodule SemanticGraph.Resources.Vertex do
  @moduledoc """
  Vertex resource representing an idea/concept in the semantic graph.

  Vertices are the nodes in our knowledge graph. Each vertex contains:
  - content: The text of the idea/concept
  - x, y: Position coordinates for graph visualization
  - group: Grouping identifier (0 or 1)

  This resource uses ETS as the data layer for fast in-memory storage.
  """

  use Ash.Resource,
    domain: SemanticGraph.GraphAPI,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "vertices"
    repo SemanticGraph.Repo
  end

  json_api do
    type "vertex"
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints max_length: 1000, min_length: 1
    end

    attribute :x, :float, default: 0.0
    attribute :y, :float, default: 0.0
    attribute :group, :integer, default: 0

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :outgoing_edges, SemanticGraph.Resources.Edge,
      destination_attribute: :from_vertex_id

    has_many :incoming_edges, SemanticGraph.Resources.Edge,
      destination_attribute: :to_vertex_id
  end

  actions do
    defaults [:read, :destroy]

    create :add_idea do
      accept [:content, :group]

      validate present(:content)
      validate string_length(:content, max: 1000, min: 1)

      # Sanitize and trim content
      change fn changeset, _context ->
        content = Ash.Changeset.get_attribute(changeset, :content)

        if content do
          sanitized = String.trim(content)
          Ash.Changeset.force_change_attribute(changeset, :content, sanitized)
        else
          changeset
        end
      end
    end

    update :update_position do
      accept [:x, :y]
    end

    update :update_content do
      accept [:content]
      validate present(:content)
      validate string_length(:content, max: 1000, min: 1)
    end
  end

  code_interface do
    define :add_idea, action: :add_idea
    define :update_position, action: :update_position
    define :update_content, action: :update_content
    define :get_by_id, action: :read, get_by: [:id]
    define :list_all, action: :read
    define :destroy, action: :destroy
  end

  validations do
    validate numericality(:group, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  end

  identities do
    # Prevent exact duplicate content (optional - remove if duplicates allowed)
    # identity :unique_content, [:content]
  end

  aggregates do
    count :outgoing_edge_count, :outgoing_edges
    count :incoming_edge_count, :incoming_edges
  end

  calculations do
    calculate :edge_count, :integer, expr(outgoing_edge_count + incoming_edge_count)
  end
end
