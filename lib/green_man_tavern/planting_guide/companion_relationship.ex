defmodule GreenManTavern.PlantingGuide.CompanionRelationship do
  use Ecto.Schema
  import Ecto.Changeset

  alias GreenManTavern.PlantingGuide.Plant

  @derive {Jason.Encoder,
           only: [
             :id,
             :plant_a_id,
             :plant_b_id,
             :relationship_type,
             :evidence_level,
             :mechanism,
             :notes,
             :inserted_at,
             :updated_at
           ]}

  schema "companion_relationships" do
    field :relationship_type, :string
    field :evidence_level, :string
    field :mechanism, :string
    field :notes, :string

    belongs_to :plant_a, Plant
    belongs_to :plant_b, Plant

    timestamps(type: :naive_datetime)
  end

  @doc false
  def changeset(companion_relationship, attrs) do
    companion_relationship
    |> cast(attrs, [
      :plant_a_id,
      :plant_b_id,
      :relationship_type,
      :evidence_level,
      :mechanism,
      :notes
    ])
    |> validate_required([:plant_a_id, :plant_b_id, :relationship_type, :evidence_level])
    |> validate_inclusion(:relationship_type, ["good", "bad"],
      message: "must be either 'good' or 'bad'"
    )
    |> validate_inclusion(
      :evidence_level,
      ["scientific", "traditional_strong", "traditional_weak"],
      message: "must be 'scientific', 'traditional_strong', or 'traditional_weak'"
    )
    |> validate_not_self_reference()
    |> unique_constraint([:plant_a_id, :plant_b_id],
      name: :companion_relationships_plant_a_id_plant_b_id_index,
      message: "this companion relationship already exists"
    )
    |> foreign_key_constraint(:plant_a_id)
    |> foreign_key_constraint(:plant_b_id)
  end

  # Custom validator to prevent a plant from being its own companion
  defp validate_not_self_reference(changeset) do
    plant_a_id = get_field(changeset, :plant_a_id)
    plant_b_id = get_field(changeset, :plant_b_id)

    if plant_a_id && plant_b_id && plant_a_id == plant_b_id do
      add_error(changeset, :plant_b_id, "cannot be the same as plant_a (no self-reference)")
    else
      changeset
    end
  end
end
