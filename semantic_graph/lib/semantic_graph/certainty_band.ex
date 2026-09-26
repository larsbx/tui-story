defmodule SemanticGraph.CertaintyBand do
  @moduledoc """
  The only Elixir module that talks to `:semantic_graph_certainty`.

  This is the boundary the Gleam kernel policy requires: a compiled Gleam
  module looks like an Erlang module from Elixir, and a codebase calling
  `:semantic_graph_certainty.classify/1` from twenty places would have a
  boundary in name only. Everything else calls this.

  The adapter owns the representation change. Gleam values arrive shaped by the
  Gleam compiler, not by us:

      Classified(Confident)  ->  {:classified, :confident}
      OutOfRange(1.5)        ->  {:out_of_range, 1.5}

  A variant carrying fields becomes a tuple tagged with its constructor; one
  carrying none becomes a bare atom. Translating that into terms this
  application already speaks is the seam where the type system stops protecting
  us, which is why it is mapped explicitly below and tested.
  """

  @type band :: :speculative | :tentative | :probable | :confident

  @doc """
  Classify a certainty into a display band.

  Returns `{:error, {:out_of_range, value}}` rather than clamping: `certainty`
  is constrained to [0.0, 1.0] by `SemanticGraph.Resources.Edge`, so a value
  outside it means something upstream is wrong and should say so.
  """
  @spec classify(float()) :: {:ok, band()} | {:error, {:out_of_range, float()}}
  def classify(certainty) when is_float(certainty) do
    case :semantic_graph_certainty.classify(certainty) do
      {:classified, band} -> {:ok, band(band)}
      {:out_of_range, value} -> {:error, {:out_of_range, value}}
    end
  end

  # Mapped one variant at a time and with no catch-all, deliberately. Adding a
  # variant on the Gleam side should break here loudly rather than fall through
  # to a default that quietly means something else.
  defp band(:speculative), do: :speculative
  defp band(:tentative), do: :tentative
  defp band(:probable), do: :probable
  defp band(:confident), do: :confident
end
