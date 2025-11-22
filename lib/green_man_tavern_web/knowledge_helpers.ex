defmodule GreenManTavernWeb.KnowledgeHelpers do
  @moduledoc """
  Helpers for identifying and marking knowledge terms in text.
  """

  alias GreenManTavern.Knowledge.TermLookup

  @doc """
  Identifies knowledge terms in text and returns segments.
  Returns a list of {:text, "regular text"} or {:term, "term", "term_key"}

  Options:
  - :seen_terms - MapSet of terms already seen (for first-occurrence-only behavior)
  """
  def identify_terms(text, opts \\ [])

  def identify_terms(text, opts) when is_binary(text) do
    terms = TermLookup.term_list()
    # Sort by length (longest first) to match longer phrases first
    sorted_terms = Enum.sort_by(terms, &String.length/1, :desc)

    seen_terms = Keyword.get(opts, :seen_terms, MapSet.new())

    identify_terms_in_text(text, sorted_terms, 0, seen_terms)
  end

  def identify_terms(text, _opts), do: [{:text, text || ""}]

  defp identify_terms_in_text(text, terms, position, seen_terms) do
    text_length = String.length(text)

    if position >= text_length do
      []
    else
      remaining_text = String.slice(text, position, text_length - position)

      case find_earliest_term_match(remaining_text, terms) do
        {term_key, match_start, match_length, matched_text} ->
          before_text = String.slice(remaining_text, 0, match_start)
          # matched_text is now directly extracted from the regex match (preserves case perfectly)
          term_key_lower = String.downcase(term_key)

          # Check if we've already seen this term
          already_seen = MapSet.member?(seen_terms, term_key_lower)
          new_seen_terms = MapSet.put(seen_terms, term_key_lower)

          segments = if before_text != "" do
            # If already seen, treat as regular text
            if already_seen do
              [{:text, before_text <> matched_text}]
            else
              [{:text, before_text}, {:term, matched_text, term_key_lower}]
            end
          else
            if already_seen do
              [{:text, matched_text}]
            else
              [{:term, matched_text, term_key_lower}]
            end
          end

          new_position = position + match_start + match_length
          segments ++ identify_terms_in_text(text, terms, new_position, new_seen_terms)

        nil ->
          [{:text, remaining_text}]
      end
    end
  end

  defp find_earliest_term_match(text, terms) do
    terms
    |> Enum.map(fn term ->
      # Case-insensitive match - use word boundaries to avoid partial matches
      pattern = ~r/\b#{Regex.escape(term)}\b/i

      # Use Regex.run to get both the match position and the actual matched string
      case Regex.run(pattern, text, return: :index) do
        nil ->
          nil
        [{byte_index, byte_length}] ->
          # Extract the actual matched text using binary_part (byte-based extraction)
          matched_string = :binary.part(text, byte_index, byte_length)
          # Convert byte index to character index for String.slice compatibility
          char_index = text |> String.slice(0, byte_index) |> String.length()
          char_length = String.length(matched_string)
          {term, char_index, char_length, matched_string}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      matches ->
        Enum.min_by(matches, fn {_term, index, _length, _matched} -> index end)
    end
  end
end
