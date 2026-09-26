defmodule SemanticGraph.CertaintyBandTest do
  @moduledoc """
  Tests the Elixir side of the Gleam boundary.

  The kernel's own behaviour is tested in Gleam, against Gleam types
  (`test/semantic_graph_certainty_test.gleam`). What is tested here is the
  thing Gleam cannot check: that the tuples and atoms its compiler emits are
  turned into the terms this application expects.
  """

  use ExUnit.Case, async: true

  alias SemanticGraph.CertaintyBand

  describe "classify/1" do
    test "maps each band across the boundary" do
      assert {:ok, :speculative} = CertaintyBand.classify(0.0)
      assert {:ok, :speculative} = CertaintyBand.classify(0.24)
      assert {:ok, :tentative} = CertaintyBand.classify(0.25)
      assert {:ok, :probable} = CertaintyBand.classify(0.5)
      assert {:ok, :confident} = CertaintyBand.classify(0.75)
      assert {:ok, :confident} = CertaintyBand.classify(1.0)
    end

    test "reports a certainty outside [0.0, 1.0] rather than clamping it" do
      assert {:error, {:out_of_range, 1.5}} = CertaintyBand.classify(1.5)
      assert {:error, {:out_of_range, -0.2}} = CertaintyBand.classify(-0.2)
    end

    test "every certainty the Edge resource permits classifies" do
      for n <- 0..100 do
        certainty = n / 100
        assert {:ok, band} = CertaintyBand.classify(certainty)
        assert band in [:speculative, :tentative, :probable, :confident]
      end
    end
  end
end
