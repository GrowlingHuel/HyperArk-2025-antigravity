defmodule GreenManTavern.Knowledge.Term do
  use Ecto.Schema
  import Ecto.Changeset

  schema "knowledge_terms" do
    field :term, :string
    field :summary, :string
    field :source, :string
    field :fetched_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(term, attrs) do
    term
    |> cast(attrs, [:term, :summary, :source, :fetched_at])
    |> validate_required([:term, :summary])
    |> unique_constraint(:term)
  end
end
