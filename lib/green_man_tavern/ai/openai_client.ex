defmodule GreenManTavern.AI.OpenAIClient do
  require Logger

  @api_url "https://openrouter.ai/api/v1/chat/completions"
  @model "openai/gpt-4o-mini"
  @max_tokens 2000

  @doc """
  Chat with GPT-4o-mini via OpenRouter.

  ## Parameters
  - message: The user's message
  - system_prompt: System instructions for the AI
  - context: Optional context (will be prepended to message if provided)

  ## Returns
  - {:ok, response_text} on success
  - {:error, reason} on failure
  """
  def chat(message, system_prompt, context \\ nil) do
    api_key = get_api_key()

    if is_nil(api_key) or api_key == "" do
      {:error, "OpenRouter API key not configured"}
    else
      full_message = build_message(message, context)

      case make_request(api_key, system_prompt, full_message) do
        {:ok, response_body} -> extract_response(response_body)
        {:error, reason} ->
          Logger.error("OpenRouter API error: #{inspect(reason)}")
          {:error, "Failed to get response from AI"}
      end
    end
  end

  defp get_api_key do
    System.get_env("OPENROUTER_API_KEY") ||
      Application.get_env(:green_man_tavern, :openrouter_api_key)
  end

  defp build_message(message, nil), do: message

  defp build_message(message, context) do
    """
    CONTEXT:
    #{context}

    USER QUESTION:
    #{message}
    """
  end

  defp make_request(api_key, system_prompt, message) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"},
      {"HTTP-Referer", "https://greenman.tavern"},
      {"X-Title", "Green Man Tavern"}
    ]

    body = %{
      model: @model,
      max_tokens: @max_tokens,
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: message}
      ]
    }

    case Req.post(@api_url, json: body, headers: headers, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status_code, body: response_body}} ->
        error_detail = case response_body do
          %{"error" => %{"message" => msg}} -> "Error: #{msg}"
          %{"error" => %{"type" => type}} -> "Error type: #{type}"
          _ -> inspect(response_body, limit: 200)
        end
        Logger.error("OpenRouter API returned status #{status_code}: #{error_detail}")

        # Provide user-friendly error messages for common status codes
        user_message = case status_code do
          401 -> "API authentication failed. Please check your OpenRouter API key."
          402 -> "Insufficient credits. Please add credits to your OpenRouter account."
          429 -> "Rate limit exceeded. Please try again in a moment."
          500 -> "OpenRouter server error. Please try again."
          503 -> "OpenRouter service temporarily unavailable. Please try again."
          _ -> "API returned status #{status_code}: #{error_detail}"
        end
        {:error, user_message}

      {:error, reason} ->
        # Check if it's a timeout error
        reason_str = inspect(reason)
        error_msg = if String.contains?(reason_str, "timeout") or String.contains?(reason_str, "Timeout") do
          Logger.error("OpenRouter API request TIMEOUT after 30 seconds")
          "Request timeout - API took too long to respond. Please try again."
        else
          Logger.error("OpenRouter API HTTP request failed: #{reason_str}")
          "HTTP request failed: #{reason_str}"
        end
        {:error, error_msg}
    end
  rescue
    error ->
      Logger.error("Exception during API request: #{inspect(error)}")
      {:error, "Request failed"}
  end

  defp extract_response(response_body) do
    case response_body do
      %{"choices" => [%{"message" => %{"content" => text}} | _]} ->
        {:ok, text}

      %{"error" => %{"message" => error_message}} ->
        {:error, error_message}

      _ ->
        {:error, "Unexpected response format: #{inspect(response_body)}"}
    end
  end
end
