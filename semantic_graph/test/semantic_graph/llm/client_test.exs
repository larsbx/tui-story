defmodule SemanticGraph.LLM.ClientTest do
  use ExUnit.Case
  alias SemanticGraph.LLM.Client

  describe "analyze_relationships/2" do
    test "returns mock relationships when no API key is configured" do
      # Ensure no API key is set
      System.delete_env("ANTHROPIC_API_KEY")
      System.delete_env("OPENAI_API_KEY")
      System.delete_env("LLM_API_KEY")

      {:ok, relationships} =
        Client.analyze_relationships("Machine learning", ["Deep learning", "Neural networks"])

      assert is_list(relationships)
      assert length(relationships) <= 2

      # Check relationship structure
      if length(relationships) > 0 do
        rel = hd(relationships)
        assert Map.has_key?(rel, :from)
        assert Map.has_key?(rel, :to)
        assert Map.has_key?(rel, :type)
        assert Map.has_key?(rel, :certainty)
        assert Map.has_key?(rel, :description)
      end
    end

    test "mock relationships have correct types" do
      System.delete_env("ANTHROPIC_API_KEY")

      {:ok, relationships} = Client.analyze_relationships("Test", ["Sample"])

      if length(relationships) > 0 do
        rel = hd(relationships)
        assert rel.type in [:analogous]
        assert rel.certainty >= 0.0 and rel.certainty <= 1.0
      end
    end
  end

  describe "Config.from_env/0" do
    test "defaults to anthropic provider" do
      System.delete_env("LLM_PROVIDER")
      config = Client.Config.from_env()
      assert config.provider == :anthropic
    end

    test "uses custom provider when set" do
      System.put_env("LLM_PROVIDER", "openai")
      config = Client.Config.from_env()
      assert config.provider == :openai
      System.delete_env("LLM_PROVIDER")
    end
  end
end
