defmodule GreenManTavern.AI.EmbeddingGenerator do
  @moduledoc """
  Generates vector embeddings for text using OpenAI's embeddings API.

  Uses the text-embedding-3-small model (1536 dimensions) which is the
  cheapest option at $0.02 per 1M tokens.
  """

  require Logger

  @api_url "https://api.openai.com/v1/embeddings"
  @model "text-embedding-3-small"
  @embedding_dimensions 1536

  @doc """
  Generates an embedding vector for the given text.

  ## Parameters
  - text: The text to generate an embedding for

  ## Returns
  - {:ok, embedding_list} where embedding_list is a list of 1536 floats
  - {:error, reason} on failure

  ## Examples

      iex> EmbeddingGenerator.generate_embedding("Build a compost bin")
      {:ok, [0.123, -0.456, ...]}
  """
  def generate_embedding(text) when is_binary(text) and text != "" do
    api_key = get_api_key()

    if is_nil(api_key) or api_key == "" do
      Logger.error("[EmbeddingGenerator] OpenAI API key not configured")
      {:error, "OpenAI API key not configured"}
    else
      case make_request(api_key, text) do
        {:ok, embedding} ->
          {:ok, embedding}

        {:error, reason} ->
          Logger.error("[EmbeddingGenerator] Failed to generate embedding: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  def generate_embedding(text) when is_binary(text) and text == "" do
    Logger.warning("[EmbeddingGenerator] Empty text provided, cannot generate embedding")
    {:error, "Empty text provided"}
  end

  def generate_embedding(_), do: {:error, "Text must be a non-empty string"}

  defp get_api_key do
    System.get_env("OPENAI_API_KEY") ||
      Application.get_env(:green_man_tavern, :openai_api_key)
  end

  defp make_request(api_key, text) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    body = %{
      model: @model,
      input: text,
      dimensions: @embedding_dimensions
    }

    case Req.post(@api_url, json: body, headers: headers, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        extract_embedding(response_body)

      {:ok, %Req.Response{status: status_code, body: response_body}} ->
        error_detail = case response_body do
          %{"error" => %{"message" => msg}} -> "Error: #{msg}"
          %{"error" => %{"type" => type}} -> "Error type: #{type}"
          _ -> inspect(response_body, limit: 200)
        end
        Logger.error("[EmbeddingGenerator] OpenAI API returned status #{status_code}: #{error_detail}")

        user_message = case status_code do
          401 -> "API authentication failed. Please check your OpenAI API key."
          402 -> "Insufficient credits. Please add credits to your OpenAI account."
          429 -> "Rate limit exceeded. Please try again in a moment."
          500 -> "OpenAI server error. Please try again."
          503 -> "OpenAI service temporarily unavailable. Please try again."
          _ -> "API returned status #{status_code}: #{error_detail}"
        end
        {:error, user_message}

      {:error, reason} ->
        reason_str = inspect(reason)
        error_msg = if String.contains?(reason_str, "timeout") or String.contains?(reason_str, "Timeout") do
          Logger.error("[EmbeddingGenerator] OpenAI API request TIMEOUT after 30 seconds")
          "Request timeout - API took too long to respond. Please try again."
        else
          Logger.error("[EmbeddingGenerator] OpenAI API HTTP request failed: #{reason_str}")
          "HTTP request failed: #{reason_str}"
        end
        {:error, error_msg}
    end
  rescue
    error ->
      Logger.error("[EmbeddingGenerator] Exception during API request: #{inspect(error)}")
      {:error, "Request failed"}
  end

  defp extract_embedding(response_body) do
    case response_body do
      %{"data" => [%{"embedding" => embedding} | _]} when is_list(embedding) ->
        # Verify embedding has correct dimensions
        if length(embedding) == @embedding_dimensions do
          {:ok, embedding}
        else
          Logger.error("[EmbeddingGenerator] Embedding has wrong dimensions: expected #{@embedding_dimensions}, got #{length(embedding)}")
          {:error, "Invalid embedding dimensions"}
        end

      %{"error" => %{"message" => error_message}} ->
        {:error, error_message}

      _ ->
        Logger.error("[EmbeddingGenerator] Unexpected response format: #{inspect(response_body, limit: 200)}")
        {:error, "Unexpected response format"}
    end
  end
end








