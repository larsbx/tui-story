defmodule SemanticGraph.LLM.Client do
  @moduledoc """
  LLM client for relationship analysis.
  Ports functionality from src/llm.zig
  """

  use Tesla

  defmodule Config do
    @moduledoc "Configuration for LLM client"

    defstruct [
      :provider,
      :model,
      :api_key,
      :endpoint,
      max_retries: 3
    ]

    def from_env do
      provider = System.get_env("LLM_PROVIDER", "anthropic") |> String.to_atom()

      %__MODULE__{
        provider: provider,
        model: get_model(provider),
        api_key: get_api_key(provider),
        endpoint: get_endpoint(provider)
      }
    end

    defp get_model(:anthropic), do: System.get_env("LLM_MODEL", "claude-3-5-sonnet-20241022")
    defp get_model(:openai), do: System.get_env("LLM_MODEL", "gpt-4")
    defp get_model(:custom), do: System.get_env("LLM_MODEL", "llama3")

    defp get_api_key(:anthropic), do: System.get_env("ANTHROPIC_API_KEY")
    defp get_api_key(:openai), do: System.get_env("OPENAI_API_KEY")
    defp get_api_key(:custom), do: System.get_env("LLM_API_KEY")

    defp get_endpoint(:anthropic), do: "https://api.anthropic.com/v1"
    defp get_endpoint(:openai), do: "https://api.openai.com/v1"

    defp get_endpoint(:custom),
      do: System.get_env("LLM_API_ENDPOINT", "http://localhost:8000")
  end

  @doc """
  Analyze relationships between a new concept and existing concepts.
  Returns list of relationships.
  """
  def analyze_relationships(new_concept, existing_concepts) do
    config = Config.from_env()

    if config.api_key do
      prompt = build_prompt(new_concept, existing_concepts)

      case call_llm(config, prompt) do
        {:ok, response} -> parse_relationships(response)
        {:error, reason} -> {:error, reason}
      end
    else
      # Fall back to mock data when no API key
      generate_mock_relationships(new_concept, existing_concepts)
    end
  end

  defp call_llm(%Config{provider: :anthropic} = config, prompt) do
    client = build_client(config)

    headers = [
      {"x-api-key", config.api_key},
      {"anthropic-version", "2023-06-01"}
    ]

    body = %{
      model: config.model,
      max_tokens: 4096,
      messages: [%{role: "user", content: prompt}]
    }

    case Tesla.post(client, "/messages", body, headers: headers) do
      {:ok, %{status: 200, body: response}} ->
        content = response["content"] |> List.first() |> Map.get("text")
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call_llm(%Config{provider: :openai} = config, prompt) do
    client = build_client(config)

    headers = [
      {"Authorization", "Bearer #{config.api_key}"}
    ]

    body = %{
      model: config.model,
      messages: [%{role: "user", content: prompt}],
      max_tokens: 4096
    }

    case Tesla.post(client, "/chat/completions", body, headers: headers) do
      {:ok, %{status: 200, body: response}} ->
        content = response["choices"] |> List.first() |> get_in(["message", "content"])
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call_llm(%Config{provider: :custom} = config, prompt) do
    client = build_client(config)

    headers =
      if config.api_key do
        [{"Authorization", "Bearer #{config.api_key}"}]
      else
        []
      end

    body = %{
      model: config.model,
      messages: [%{role: "user", content: prompt}],
      max_tokens: 4096
    }

    case Tesla.post(client, "/chat/completions", body, headers: headers) do
      {:ok, %{status: 200, body: response}} ->
        content = response["choices"] |> List.first() |> get_in(["message", "content"])
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_client(config) do
    middleware = [
      {Tesla.Middleware.BaseUrl, config.endpoint},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Retry,
       delay: 1000, max_retries: 3, max_delay: 8_000, should_retry: &should_retry?/1},
      {Tesla.Middleware.Timeout, timeout: 30_000}
    ]

    Tesla.client(middleware)
  end

  defp should_retry?({:ok, %{status: status}}) when status in 500..599, do: true
  defp should_retry?({:ok, _}), do: false
  defp should_retry?({:error, _}), do: true

  defp build_prompt(new_concept, existing_concepts) do
    """
    Analyze the semantic relationships between the new concept and existing concepts.

    NEW CONCEPT:
    #{new_concept}

    EXISTING CONCEPTS:
    #{Enum.map_join(existing_concepts, "\n", &("- " <> &1))}

    For each relevant relationship, provide:
    1. From concept
    2. To concept
    3. Relationship type (one of: contradictory, implicative, hierarchical, evolutionary, analogous, synonymous, antonymous, part_whole, causal)
    4. Certainty (0.0 to 1.0)
    5. Description

    Format your response as JSON array of objects with fields: from, to, type, certainty, description.
    Only include the JSON array in your response, no other text.
    """
  end

  defp parse_relationships(response_text) do
    # Try to extract JSON from the response
    json_text =
      response_text
      |> String.trim()
      |> extract_json()

    case Jason.decode(json_text) do
      {:ok, relationships} when is_list(relationships) ->
        {:ok, Enum.map(relationships, &map_relationship/1)}

      {:ok, _} ->
        {:error, :invalid_format}

      {:error, _} ->
        {:error, :parse_error}
    end
  end

  defp extract_json(text) do
    # Try to find JSON array in the text
    case Regex.run(~r/\[.*\]/s, text) do
      [json] -> json
      nil -> text
    end
  end

  defp map_relationship(data) do
    %{
      from: data["from"],
      to: data["to"],
      type: String.to_atom(data["type"]),
      certainty: data["certainty"],
      description: data["description"]
    }
  end

  defp generate_mock_relationships(new_concept, existing_concepts) do
    # Simple mock for testing without API key
    relationships =
      existing_concepts
      |> Enum.take(2)
      |> Enum.map(fn existing ->
        %{
          from: new_concept,
          to: existing,
          type: :analogous,
          certainty: 0.75,
          description: "Mock relationship for testing"
        }
      end)

    {:ok, relationships}
  end
end
