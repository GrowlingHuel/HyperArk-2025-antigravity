defmodule GreenManTavern.Knowledge.TermLookup do
  @moduledoc """
  Fetches term summaries from Wikipedia or other open-source sources.
  """

  require Logger

  # Common terms that should have popups
  @term_list [
    "permaculture",
    "fermentation",
    "compost",
    "mulch",
    "biodiversity",
    "organic",
    "sustainable",
    "regenerative",
    "mycelium",
    "vermicompost",
    "guild",
    "polyculture",
    "monoculture",
    "guild",
    "guild planting",
    "companion planting",
    "cider",
    "yeast",
    "must",
    "airlock",
    "hyphae",
    "substrate",
    "inoculation",
    "spawn"
  ]

  @doc """
  Returns a list of terms that should have popups.
  """
  def term_list, do: @term_list

  @doc """
  Fetches a term summary from Wikipedia (used internally by Knowledge context).
  Returns {:ok, summary} or {:error, reason}

  Note: For application use, prefer GreenManTavern.Knowledge.get_term_summary/1
  which includes database caching.
  """
  def fetch_summary(term) do
    term_lower = String.downcase(term)

    # Try Wikipedia API
    case fetch_from_wikipedia(term_lower) do
      {:ok, summary} -> {:ok, summary}
      {:error, _reason} ->
        # Could add fallback to other sources here
        {:error, "Summary not available"}
    end
  end

  defp fetch_from_wikipedia(term) do
    # Wikipedia API: extract first paragraph
    url = "https://en.wikipedia.org/api/rest_v1/page/summary/#{URI.encode(term)}"

    headers = [
      {"User-Agent", "GreenManTavern/1.0 (contact@greenman.tavern)"}
    ]

    case Req.get(url, headers: headers, receive_timeout: 5_000) do
      {:ok, %Req.Response{status: 200, body: %{"extract" => extract}}} ->
        # Use the full extract from Wikipedia (typically 2-3 paragraphs)
        # This is usually around 500-800 characters, approximately 100-150 words
        # which gives a good overview without being overwhelming
        summary = if String.length(extract) > 0 do
          extract
        else
          "Summary not available"
        end

        {:ok, summary}

      {:ok, %Req.Response{status: 404}} ->
        {:error, "Term not found on Wikipedia"}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Wikipedia API returned status #{status} for term: #{term}")
        {:error, "API returned status #{status}"}

      {:error, reason} ->
        Logger.warning("Wikipedia API request failed for term #{term}: #{inspect(reason)}")
        {:error, "Request failed"}
    end
  rescue
    error ->
      Logger.error("Exception fetching Wikipedia summary: #{inspect(error)}")
      {:error, "Request failed"}
  end
end
