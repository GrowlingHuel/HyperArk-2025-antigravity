defmodule GreenManTavern.EctoTypes.VectorType do
  @moduledoc """
  Custom Ecto type for pgvector vector columns.

  Handles conversion between PostgreSQL vector type and Elixir data structures.
  Since we use raw SQL for vector operations, we primarily need this for loading data.
  """
  use Ecto.Type

  def type, do: :vector

  # Cast from various input formats
  def cast(value) when is_list(value) do
    # List of floats (from embedding generator)
    if Enum.all?(value, &is_float/1) do
      {:ok, value}
    else
      :error
    end
  end

  def cast(value) when is_binary(value) do
    # PostgreSQL array string format: "[0.1,0.2,0.3]"
    case parse_vector_string(value) do
      {:ok, list} -> {:ok, list}
      :error -> :error
    end
  end

  def cast(_), do: :error

  # Load from database (PostgreSQL vector type)
  def load(value) when is_binary(value) do
    # PostgreSQL returns vector as binary array format
    # We'll parse it as a string representation
    case parse_vector_string(value) do
      {:ok, list} -> {:ok, list}
      :error -> {:ok, []}  # Return empty list on parse error
    end
  end

  def load(_), do: {:ok, []}

  # Dump to database (we use raw SQL, so this may not be called)
  def dump(value) when is_list(value) do
    # Convert list to PostgreSQL array string format
    array_str = "[" <> Enum.join(Enum.map(value, &Float.to_string/1), ",") <> "]"
    {:ok, array_str}
  end

  def dump(_), do: :error

  # Parse PostgreSQL vector/array string format
  defp parse_vector_string(str) when is_binary(str) do
    # Remove brackets and split by comma
    cleaned = str
              |> String.trim()
              |> String.trim_leading("[")
              |> String.trim_trailing("]")

    if cleaned == "" do
      {:ok, []}
    else
      values = cleaned
               |> String.split(",")
               |> Enum.map(&String.trim/1)
               |> Enum.map(&parse_float/1)

      if Enum.all?(values, &match?({:ok, _}, &1)) do
        floats = Enum.map(values, fn {:ok, f} -> f end)
        {:ok, floats}
      else
        :error
      end
    end
  end

  defp parse_float(str) do
    case Float.parse(str) do
      {float, _} -> {:ok, float}
      :error -> :error
    end
  end
end








