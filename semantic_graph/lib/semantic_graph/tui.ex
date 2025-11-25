defmodule SemanticGraph.TUI do
  @moduledoc """
  Terminal UI for semantic graph application.
  Built with Ratatouille - maintains Zig TUI experience.

  Ports functionality from src/ui.zig
  """

  @behaviour Ratatouille.App

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1, color: 1, attribute: 1]

  alias SemanticGraph.GraphAPI
  alias SemanticGraph.Resources.{Vertex, Edge}

  # State struct - mirrors ui.zig:10-19
  defmodule State do
    @type mode :: :help | :input | :analyzing | :viewing_graph | :confirming_reset

    @type t :: %__MODULE__{
            mode: mode(),
            ideas: list(String.t()),
            current_input: String.t(),
            selected_edge: non_neg_integer() | nil,
            error_message: String.t() | nil,
            graph: map() | nil,
            analyzing: boolean(),
            analysis_task: Task.t() | nil,
            frame_count: non_neg_integer()
          }

    defstruct mode: :help,
              ideas: [],
              current_input: "",
              selected_edge: nil,
              error_message: nil,
              graph: nil,
              analyzing: false,
              analysis_task: nil,
              frame_count: 0
  end

  # Ratatouille Callbacks

  @impl true
  def init(_context) do
    # Load existing graph data if any
    vertices = Vertex.list_all!()

    %State{
      ideas: Enum.map(vertices, & &1.content),
      graph:
        if length(vertices) > 0 do
          %{vertices: vertices, edges: Edge.list_all!()}
        end
    }
  end

  @impl true
  def update(model, msg) do
    # Increment frame counter for animations
    model = %{model | frame_count: model.frame_count + 1}

    # Handle events based on current mode
    case {model.mode, msg} do
      # Help mode handlers (port from ui.zig:65-78)
      {:help, {:event, %{ch: ?e}}} ->
        %{model | mode: :input, current_input: "", error_message: nil}

      {:help, {:event, %{ch: ?v}}} when length(model.ideas) > 0 ->
        %{model | mode: :viewing_graph, selected_edge: nil}

      {:help, {:event, %{ch: ?r}}} ->
        # Show confirmation dialog before resetting
        %{model | mode: :confirming_reset}

      {:help, {:event, %{ch: ?q}}} ->
        Ratatouille.Runtime.shutdown()
        model

      # Confirmation dialog handlers
      {:confirming_reset, {:event, %{ch: ?y}}} ->
        reset_graph()
        %{model | ideas: [], graph: nil, mode: :help}

      {:confirming_reset, {:event, %{ch: ?n}}} ->
        %{model | mode: :help}

      {:confirming_reset, {:event, %{key: key(:esc)}}} ->
        %{model | mode: :help}

      # Input mode handlers (port from ui.zig:80-119)
      {:input, {:event, %{key: key(:enter)}}} when model.current_input != "" ->
        handle_idea_submission(model)

      {:input, {:event, %{key: key(:esc)}}} ->
        %{model | mode: :help, current_input: "", error_message: nil}

      {:input, {:event, %{key: key(:backspace)}}} ->
        %{model | current_input: String.slice(model.current_input, 0..-2//1)}

      {:input, {:event, %{ch: ch}}} when ch >= 32 and ch < 127 ->
        %{model | current_input: model.current_input <> <<ch::utf8>>}

      # Analyzing mode
      {:analyzing, {:event, %{key: key(:esc)}}} ->
        # Cancel analysis task if running
        if model.analysis_task do
          Task.shutdown(model.analysis_task, :brutal_kill)
        end

        %{model | mode: :help, analysis_task: nil}

      # Viewing graph mode (port from ui.zig:130-158)
      {:viewing_graph, {:event, %{key: key(:esc)}}} ->
        %{model | mode: :help}

      {:viewing_graph, {:event, %{ch: ?h}}} ->
        %{model | mode: :help}

      {:viewing_graph, {:event, %{key: key(:arrow_up)}}} ->
        %{model | selected_edge: move_selection(model.selected_edge, :up, model.graph)}

      {:viewing_graph, {:event, %{key: key(:arrow_down)}}} ->
        %{model | selected_edge: move_selection(model.selected_edge, :down, model.graph)}

      {:viewing_graph, {:event, %{ch: ?q}}} ->
        Ratatouille.Runtime.shutdown()
        model

      # Timer events for checking task completion
      {_, {:timer, _}} ->
        check_analysis_task(model)

      _ ->
        model
    end
  end

  @impl true
  def render(model) do
    case model.mode do
      :help -> render_help(model)
      :input -> render_input(model)
      :analyzing -> render_analyzing(model)
      :viewing_graph -> render_graph(model)
      :confirming_reset -> render_confirming_reset(model)
    end
  end

  @impl true
  def subscribe(_model) do
    # Subscribe to timer events for checking async task completion
    Ratatouille.Runtime.subscribe(:timer, 100)
  end

  # Rendering Functions

  defp render_help(model) do
    view do
      panel(title: "Semantic Relationship Graph Analyzer", height: :fill) do
        row do
          column(size: 12) do
            label(content: "")
            label(content: "Welcome! Enter ideas one at a time and watch your semantic graph grow.")

            label(
              content:
                "Each new idea is analyzed against all existing ideas to discover relationships."
            )

            label(content: "")
            label(content: "Status:", attributes: [color(:yellow)])

            ideas_count = length(model.ideas)

            label(
              content: "  Ideas in graph: #{ideas_count}",
              attributes: [color(if ideas_count > 0, do: :green, else: :white)]
            )

            edges_count = if model.graph, do: length(model.graph.edges), else: 0

            label(
              content: "  Relationships found: #{edges_count}",
              attributes: [color(if edges_count > 0, do: :green, else: :white)]
            )

            label(content: "")
            label(content: "Commands:", attributes: [color(:yellow)])
            label(content: "  [e] - Enter a new idea")

            if ideas_count > 0 do
              label(content: "  [v] - View graph")
            else
              label(
                content: "  [v] - View graph (disabled - add ideas first)",
                attributes: [color(:red)]
              )
            end

            label(content: "  [r] - Reset all data")
            label(content: "  [q] - Quit")

            if ideas_count > 0 do
              label(content: "")
              label(content: "Your Ideas:", attributes: [color(:cyan)])

              for {idea, idx} <- Enum.with_index(model.ideas, 1) do
                label(content: "  #{idx}. #{idea}")
              end
            end

            # Show Graphiti status
            graphiti_enabled =
              try do
                SemanticGraph.Graphiti.Integration.enabled?()
              rescue
                _ -> false
              end

            if graphiti_enabled do
              label(content: "")
              label(content: "Graphiti: ✓ Connected", attributes: [color(:green)])
            else
              label(content: "")

              label(
                content: "Graphiti: ✗ Unavailable (using fallback mode)",
                attributes: [color(:yellow)]
              )
            end
          end
        end
      end
    end
  end

  defp render_input(model) do
    title_text =
      if length(model.ideas) == 0 do
        "Enter your first idea"
      else
        "Enter another idea (#{length(model.ideas)} existing)"
      end

    view do
      panel(title: title_text, height: :fill) do
        row do
          column(size: 12) do
            if length(model.ideas) > 0 do
              label(
                content:
                  "Your new idea will be compared to all #{length(model.ideas)} existing ideas"
              )

              label(content: "")
            end

            label(content: "> #{model.current_input}_", attributes: [color(:green)])

            if model.error_message do
              label(content: "")
              label(content: model.error_message, attributes: [color(:red)])
            end

            label(content: "")

            label(
              content: "[Enter] Submit idea  [Esc] Back to menu",
              attributes: [color(:white)]
            )
          end
        end
      end
    end
  end

  defp render_analyzing(model) do
    # Animated spinner: ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
    spinners = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    spinner = Enum.at(spinners, rem(model.frame_count, length(spinners)))

    view do
      panel(title: "Analyzing", height: :fill) do
        row do
          column(size: 12) do
            label(content: "")

            label(
              content: "   #{spinner} Analyzing semantic relationships...",
              attributes: [color(:yellow)]
            )

            label(content: "   Please wait while the LLM processes your idea.")
            label(content: "")
            label(content: "   [Esc] Cancel analysis", attributes: [color(:white)])
          end
        end
      end
    end
  end

  defp render_confirming_reset(model) do
    ideas_count = length(model.ideas)
    edges_count = if model.graph, do: length(model.graph.edges), else: 0

    view do
      panel(title: "⚠️  Confirm Reset", height: :fill) do
        row do
          column(size: 12) do
            label(content: "")
            label(content: "   WARNING: You are about to reset all data!", attributes: [color(:red)])
            label(content: "")
            label(content: "   This will permanently delete:")
            label(content: "     • #{ideas_count} ideas", attributes: [color(:yellow)])
            label(content: "     • #{edges_count} relationships", attributes: [color(:yellow)])
            label(content: "")
            label(content: "   This action cannot be undone.", attributes: [color(:red)])
            label(content: "")
            label(content: "   Are you sure you want to continue?")
            label(content: "")
            label(content: "   [y] Yes, reset all data  [n] No, go back", attributes: [color(:white)])
            label(content: "   [Esc] Cancel", attributes: [color(:white)])
          end
        end
      end
    end
  end

  defp render_graph(model) do
    view do
      panel(title: "Semantic Relationship Graph", height: :fill) do
        row do
          column(size: 12) do
            # Render vertices
            label(content: "Vertices:", attributes: [color(:cyan)])

            for vertex <- model.graph.vertices do
              label(content: "  • #{vertex.content}")
            end

            label(content: "")
            label(content: "Relationships:", attributes: [color(:cyan)])

            # Render edges with selection
            for {edge, idx} <- Enum.with_index(model.graph.edges) do
              is_selected = model.selected_edge == idx

              attrs =
                if is_selected,
                  do: [color(:black), attribute(:reverse)],
                  else: []

              from = Enum.find(model.graph.vertices, &(&1.id == edge.from_vertex_id))
              to = Enum.find(model.graph.vertices, &(&1.id == edge.to_vertex_id))
              symbol = relationship_symbol(edge.relation_type)

              content =
                "  #{truncate(from.content, 30)} #{symbol} #{truncate(to.content, 30)} (#{Float.round(edge.certainty, 2)})"

              label(content: content, attributes: attrs)
            end

            label(content: "")
            label(content: "Legend:", attributes: [color(:yellow)])
            label(content: "  → Implicative  ⊆ Hierarchical  ⇒ Causal")
            label(content: "  ⊥ Contradictory  ≡ Synonymous  ≈ Analogous")

            label(content: "")

            label(
              content: "[↑↓] Navigate  [h/Esc] Menu  [q] Quit",
              attributes: [color(:white)]
            )
          end
        end
      end
    end
  end

  defp relationship_symbol(type) do
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

  defp truncate(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length - 3) <> "..."
    else
      text
    end
  end

  # Helper Functions

  defp handle_idea_submission(model) do
    content = String.trim(model.current_input)

    if valid_idea?(content) do
      # Start async analysis
      task = SemanticGraph.Analysis.Service.analyze_new_idea_async(content)

      %{model
        | mode: :analyzing,
          current_input: "",
          analysis_task: task,
          error_message: nil
      }
    else
      %{model | error_message: "Invalid input (1-1000 characters required)"}
    end
  end

  defp check_analysis_task(model) do
    if model.mode == :analyzing && model.analysis_task do
      case Task.yield(model.analysis_task, 0) do
        {:ok, {:ok, result}} ->
          # Analysis complete - update graph
          %{model
            | mode: :viewing_graph,
              ideas: [result.vertex.content | model.ideas],
              graph: %{
                vertices: Vertex.list_all!(),
                edges: Edge.list_all!()
              },
              analysis_task: nil
          }

        {:ok, {:error, reason}} ->
          # Analysis failed
          %{model
            | mode: :input,
              error_message: "Analysis failed: #{inspect(reason)}",
              analysis_task: nil
          }

        nil ->
          # Still running, keep waiting
          model
      end
    else
      model
    end
  end

  defp valid_idea?(content) do
    length = String.length(content)
    length >= 1 && length <= 1000
  end

  defp reset_graph do
    Vertex.list_all!()
    |> Enum.each(&Ash.destroy!/1)
  end

  defp move_selection(nil, :down, graph)
       when is_map(graph) and not is_nil(graph.edges) and length(graph.edges) > 0,
       do: 0

  defp move_selection(nil, :up, _graph), do: nil
  defp move_selection(idx, :up, _graph) when idx > 0, do: idx - 1
  defp move_selection(idx, :up, _graph), do: idx

  defp move_selection(idx, :down, graph) when idx < length(graph.edges) - 1, do: idx + 1
  defp move_selection(idx, :down, _graph), do: idx
end
