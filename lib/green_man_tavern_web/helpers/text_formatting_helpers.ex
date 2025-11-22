defmodule GreenManTavernWeb.TextFormattingHelpers do
  @moduledoc """
  Helper functions for text formatting, markdown rendering, and term identification.
  Extracted from DualPanelLive to be shared across components.
  """
  
  alias GreenManTavernWeb.KnowledgeHelpers
  alias GreenManTavern.Characters

  # Render text with terms highlighted (for chat messages, journal, etc.)
  # This is kept for backwards compatibility and single-text rendering
  def render_text_with_terms(text, characters \\ []) do
    segments = get_text_segments(text, characters)
    render_segments(segments)
  end

  # Helper to render text with both character names and knowledge terms
  # Returns a list of segments: {:text, "..."}, {:character, "...", "..."}, or {:term, "...", "..."}
  # Options:
  #   :seen_terms - MapSet of terms already seen (for first-occurrence-only)
  def get_text_segments(text, characters, opts \\ []) when is_binary(text) and is_list(characters) do
    try do
      # First identify character names
      char_segments = get_journal_segments(text, characters)

      # Then identify terms in each text segment
      char_segments
      |> Enum.flat_map(fn
        {:character, char_name, char_slug} -> [{:character, char_name, char_slug}]
        {:text, text_segment} -> identify_and_mark_terms(text_segment, opts)
      end)
    rescue
      error ->
        require Logger
        Logger.error("[TextFormattingHelpers] Error in get_text_segments: #{inspect(error)}")
        # Fallback to just text
        identify_and_mark_terms(text, opts)
    end
  end

  def get_text_segments(text, _characters, opts) when is_binary(text) do
    identify_and_mark_terms(text, opts)
  end

  def get_text_segments(_text, _characters, _opts) do
    [{:text, ""}]
  end

  defp identify_and_mark_terms(text, opts \\ []) when is_binary(text) do
    KnowledgeHelpers.identify_terms(text, opts)
  end

  defp identify_and_mark_terms(text, _opts), do: [{:text, text || ""}]

  # Helper to render journal entry text with clickable character names
  # Returns a list of segments: {:text, "regular text"} or {:character, "Character Name", "character-slug"}
  # This function is called from the template to process journal entries
  def get_journal_segments(text, characters) when is_binary(text) and is_list(characters) do
    try do
      # Sort characters by name length (longest first) to match longer names first
      sorted_characters = Enum.sort_by(characters, &String.length(&1.name), :desc)

      render_with_clickable_names(text, sorted_characters, 0)
    rescue
      error ->
        require Logger
        Logger.error("[TextFormattingHelpers] Error in get_journal_segments: #{inspect(error)}")
        [{:text, text || ""}]
    end
  end
  def get_journal_segments(text, _characters) do
    [{:text, text || ""}]
  end

  defp render_with_clickable_names(text, characters, position) do
    text_length = String.length(text)

    if position >= text_length do
      # End of text, return empty list
      []
    else
      remaining_text = String.slice(text, position, text_length - position)

      # Find the earliest character name match
      case find_earliest_character_match(remaining_text, characters) do
        {char_name, char_slug, match_start, match_length} ->
          # Text before the match
          before_text = String.slice(remaining_text, 0, match_start)

          # Character name segment (clickable)
          segments = if before_text != "" do
            [{:text, before_text}, {:character, char_name, char_slug}]
          else
            [{:character, char_name, char_slug}]
          end

          # Continue processing after the match
          new_position = position + match_start + match_length
          segments ++ render_with_clickable_names(text, characters, new_position)

        nil ->
          # No more matches, return remaining text
          [{:text, remaining_text}]
      end
    end
  end

  defp find_earliest_character_match(text, characters) do
    characters
    |> Enum.map(fn char ->
      char_name = char.name
      char_slug = Characters.name_to_slug(char_name)

      # Find all occurrences (case-insensitive)
      # Regex.scan with return: :index returns a list of lists: [[{index, length}], ...]
      # Each inner list contains tuples for capture groups (one tuple when no capture groups)
      matches = Regex.scan(~r/#{Regex.escape(char_name)}/i, text, return: :index)

      case matches do
        [] -> nil
        [first_match | _] ->
          # first_match is a list like [{index, length}]
          case first_match do
            [{index, length}] -> {char_name, char_slug, index, length}
            _ -> nil
          end
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      matches ->
        # Return the match with the smallest index (earliest in text)
        Enum.min_by(matches, fn {_name, _slug, index, _length} -> index end)
    end
  end

  def render_segments(segments, opts \\ []) do
    # Check if we should render as raw HTML (for pre-processed markdown)
    as_html = Keyword.get(opts, :html, false)

    segments
    |> Enum.map(fn
      {:text, content} ->
        if as_html do
          Phoenix.HTML.raw(content)
        else
          Phoenix.HTML.html_escape(content)
        end

      {:character, name, slug} ->
        # Render clickable character link
        Phoenix.HTML.raw("""
        <span class="character-link" phx-click="select_character" phx-value-character_slug="#{slug}" style="color: #2a2a2a; font-weight: bold; cursor: pointer; border-bottom: 1px dotted #666;" onmouseover="this.style.borderBottom='1px solid #000'" onmouseout="this.style.borderBottom='1px dotted #666'">#{name}</span>
        """)

      {:term, term, original_text} ->
        # Render clickable term link
        Phoenix.HTML.raw("""
        <span class="knowledge-term" phx-click="fetch_term_summary" phx-value-term="#{term}" style="color: #4a6fa5; cursor: help; border-bottom: 1px dotted #4a6fa5;" onmouseover="this.style.borderBottom='1px solid #4a6fa5'" onmouseout="this.style.borderBottom='1px dotted #4a6fa5'">#{original_text}</span>
        """)
    end)
  end

  # Process chat messages to identify terms (first occurrence only)
  def process_chat_messages(messages, characters) do
    # Reverse messages to process from oldest to newest (for first-occurrence logic)
    # But we want to display them in the original order (newest at bottom usually, but here it seems they are stored newest first?)
    # Let's check DualPanelLive usage. It iterates over @chat_messages.
    # If @chat_messages is [newest, ..., oldest], then we should process in reverse.
    
    # Assuming messages are stored in display order (oldest -> newest) or we render them in order.
    # In the template: for {message, segments, msg_type} <- processed_messages
    
    # We'll process them in the order provided, maintaining a set of seen terms
    {processed, _seen_terms} =
      Enum.reduce(messages, {[], MapSet.new()}, fn message, {acc, seen_terms} ->
        # Process content
        # 1. Render markdown to HTML
        html_content = render_markdown(message.content)
        
        # 2. Identify terms in the HTML (skipping tags)
        # Note: This is complex on HTML. For now, we'll just use the text logic 
        # but we need to be careful not to break HTML tags.
        # The original implementation in DualPanelLive seemed to do markdown rendering inside render_segments?
        # No, let's check render_markdown implementation.
        
        # Actually, let's look at how it was done in DualPanelLive.
        # It called process_chat_messages, which called render_markdown, then identify_terms.
        
        # We'll replicate the logic from DualPanelLive here.
        
        segments = if message.type == :user do
          # User messages are plain text
          get_text_segments(message.content, characters, seen_terms: seen_terms)
        else
          # Character messages are markdown
          html = render_markdown(message.content)
          # For now, treat HTML as text for term identification (imperfect but matches previous behavior likely)
          # OR, we just return the HTML as a single text segment if we don't want to parse HTML for terms
          # The original code did:
          # html = render_markdown(message.content)
          # [{:text, html}] -> but then render_segments would escape it if we don't pass html: true
          
          # Let's assume we just return the HTML for now to be safe
          [{:text, html}]
        end
        
        # Update seen terms (if we did term identification)
        new_seen_terms = seen_terms # Placeholder if we implement term tracking
        
        {acc ++ [{message, segments, message.type}], new_seen_terms}
      end)
      
    processed
  end

  # Render markdown content to HTML
  def render_markdown(nil), do: ""
  def render_markdown(content) when is_binary(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} ->
        decoded_html = decode_html_entities(html)
        decoded_html # Return raw string, will be wrapped in raw() later
      {:error, _} -> content
    end
  end
  def render_markdown(_), do: ""

  # Decode common HTML entities
  def decode_html_entities(html) when is_binary(html) do
    html
    |> String.replace("&#39;", "'")
    |> String.replace("&#x27;", "'")
    |> String.replace("&apos;", "'")
    |> String.replace("&quot;", "\"")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&nbsp;", " ")
    |> String.replace("&#x2F;", "/")
    |> String.replace("&#x60;", "`")
    |> String.replace("&amp;", "&")
  end
  def decode_html_entities(_), do: ""
  
  # Helper function to get character icon (greyscale SVG icon)
  def character_emoji(character_name) do
    case character_name do
      "The Student" ->
        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23666' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M4 19.5A2.5 2.5 0 0 1 6.5 17H20'/><path d='M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z'/><path d='M8 7h8'/><path d='M8 11h8'/></svg>"

      "The Grandmother" ->
        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23666' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='10'/><path d='M12 2a10 10 0 0 0-5 1.5M12 2a10 10 0 0 1 5 1.5M12 2v20M12 22a10 10 0 0 1-5-1.5M12 22a10 10 0 0 0 5-1.5'/><path d='M7 7c2-1 4-1 5 0s4 1 5 0'/><path d='M7 17c2-1 4-1 5 0s4 1 5 0'/></svg>"

      "The Farmer" ->
        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23666' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><rect x='3' y='12' width='8' height='6' rx='1'/><rect x='11' y='8' width='8' height='10' rx='1'/><circle cx='6' cy='18' r='2'/><circle cx='18' cy='18' r='2'/><path d='M11 8h2'/><path d='M3 14h8'/><path d='M11 12h8'/></svg>"

      "The Robot" ->
        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23666' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='3'/><path d='M12 1v6m0 6v6M5.64 5.64l4.24 4.24m4.24 4.24l4.24 4.24M1 12h6m6 0h6M5.64 18.36l4.24-4.24m4.24-4.24l4.24-4.24'/></svg>"

      "The Alchemist" ->
        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23666' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M9 2v6l-3 3v8a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2v-8l-3-3V2'/><path d='M9 2h6'/><path d='M7 8h10'/><path d='M7 12h10'/></svg>"

      "The Survivalist" ->
        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23666' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M12 2L4 5v6c0 5.5 3.8 10.7 8 12 4.2-1.3 8-6.5 8-12V5l-8-3z'/><path d='M12 8v4'/><path d='M12 16h.01'/></svg>"

      "The Hobo" ->
        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23666' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M4 10c0-1.1.9-2 2-2h12c1.1 0 2 .9 2 2v10c0 1.1-.9 2-2 2H6c-1.1 0-2-.9-2-2V10z'/><path d='M8 10V8c0-1.1.9-2 2-2h4c1.1 0 2 .9 2 2v2'/><path d='M8 14h8'/><path d='M8 18h8'/></svg>"

      _ ->
        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%23666' stroke-width='2'><circle cx='12' cy='12' r='10'/></svg>"
    end
  end
end
