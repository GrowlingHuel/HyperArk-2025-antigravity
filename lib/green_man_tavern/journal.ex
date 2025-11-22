defmodule GreenManTavern.Journal do
  import Ecto.Query
  alias GreenManTavern.Repo
  alias GreenManTavern.Journal.Entry

  def list_entries(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    include_hidden = Keyword.get(opts, :include_hidden, false)

    query =
      Entry
      |> where([e], e.user_id == ^user_id)

    query =
      if include_hidden do
        query
      else
        where(query, [e], e.hidden == false)
      end

    query
    |> order_by([e], asc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_entry!(id), do: Repo.get!(Entry, id)

  def create_entry(attrs \\ %{}) do
    %Entry{}
    |> Entry.changeset(attrs)
    |> Repo.insert()
  end

  def update_entry(%Entry{} = entry, attrs) do
    entry
    |> Entry.changeset(attrs)
    |> Repo.update()
  end

  def delete_entry(%Entry{} = entry) do
    Repo.delete(entry)
  end

  def search_entries(user_id, search_term, opts \\ []) when is_binary(search_term) do
    search_pattern = "%#{String.replace(search_term, ~r/[%_]/, fn
      "%" -> "\\%"
      "_" -> "\\_"
    end)}%"
    include_hidden = Keyword.get(opts, :include_hidden, false)

    query =
      Entry
      |> where([e], e.user_id == ^user_id)
      |> where([e],
        (is_nil(e.title) == false and ilike(e.title, ^search_pattern)) or
        ilike(e.body, ^search_pattern) or
        (is_nil(e.entry_date) == false and ilike(e.entry_date, ^search_pattern))
      )

    query =
      if include_hidden do
        query
      else
        where(query, [e], e.hidden == false)
      end

    query
    |> order_by([e], asc: e.inserted_at)
    |> Repo.all()
  end

  def get_max_day_number(user_id) do
    Entry
    |> where([e], e.user_id == ^user_id)
    |> select([e], max(e.day_number))
    |> Repo.one()
    |> case do
      nil -> 0
      max_day -> max_day
    end
  end

  def format_entry_date(day_number) do
    # Simple format: "Day N" or could be more elaborate later
    ordinal = get_ordinal(day_number)
    "Day #{day_number}"
  end

  defp get_ordinal(n) when rem(n, 10) == 1 and rem(n, 100) != 11, do: "st"
  defp get_ordinal(n) when rem(n, 10) == 2 and rem(n, 100) != 12, do: "nd"
  defp get_ordinal(n) when rem(n, 10) == 3 and rem(n, 100) != 13, do: "rd"
  defp get_ordinal(_n), do: "th"
end
