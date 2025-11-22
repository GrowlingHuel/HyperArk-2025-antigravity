defmodule GreenManTavern.Knowledge do
  @moduledoc """
  Context for managing knowledge terms and their summaries.
  Provides caching layer for term definitions fetched from external sources.
  """

  import Ecto.Query, warn: false
  alias GreenManTavern.Repo
  alias GreenManTavern.Knowledge.{Term, TermLookup}

  @doc """
  Gets a term summary, checking database first, then fetching from Wikipedia if needed.
  """
  def get_term_summary(term) do
    term_lower = String.downcase(term)

    # Check database first
    case Repo.get_by(Term, term: term_lower) do
      nil ->
        # Not in database, fetch from Wikipedia and cache
        fetch_and_cache_term(term_lower)

      cached_term ->
        # Return cached summary
        {:ok, cached_term.summary}
    end
  end

  @doc """
  Creates or updates a term in the database.
  """
  def create_or_update_term(term, summary, source \\ "wikipedia") do
    term_lower = String.downcase(term)
    now = DateTime.utc_now()

    attrs = %{
      term: term_lower,
      summary: summary,
      source: source,
      fetched_at: now
    }

    case Repo.get_by(Term, term: term_lower) do
      nil ->
        # Create new
        %Term{}
        |> Term.changeset(attrs)
        |> Repo.insert()

      existing_term ->
        # Update existing
        existing_term
        |> Term.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Seeds all terms from TermLookup.term_list() by fetching from Wikipedia.
  """
  def seed_terms do
    require Logger
    terms = TermLookup.term_list()

    Logger.info("Seeding #{length(terms)} knowledge terms...")

    results = Enum.map(terms, fn term ->
      case TermLookup.fetch_summary(term) do
        {:ok, summary} ->
          case create_or_update_term(term, summary) do
            {:ok, _} ->
              Logger.info("✓ Cached term: #{term}")
              :ok
            {:error, changeset} ->
              Logger.error("✗ Failed to cache #{term}: #{inspect(changeset.errors)}")
              :error
          end

        {:error, reason} ->
          Logger.warning("✗ Failed to fetch #{term}: #{inspect(reason)}")
          :error
      end
    end)

    success_count = Enum.count(results, &(&1 == :ok))
    Logger.info("Seeding complete: #{success_count}/#{length(terms)} terms cached")

    {:ok, success_count}
  end

  defp fetch_and_cache_term(term) do
    require Logger

    # Fetch from Wikipedia
    case TermLookup.fetch_summary(term) do
      {:ok, summary} ->
        # Cache it in the database
        case create_or_update_term(term, summary) do
          {:ok, _} ->
            Logger.debug("Cached new term: #{term}")
            {:ok, summary}

          {:error, changeset} ->
            Logger.error("Failed to cache term #{term}: #{inspect(changeset.errors)}")
            # Still return the summary even if caching failed
            {:ok, summary}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
