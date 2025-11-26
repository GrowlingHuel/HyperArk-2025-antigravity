defmodule GreenManTavern.Rack.PatchCable do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "patch_cables" do
    field :source_jack_id, :string
    field :target_jack_id, :string
    field :cable_color, :string

    belongs_to :user, GreenManTavern.Accounts.User, type: :id
    belongs_to :source_device, GreenManTavern.Rack.Device
    belongs_to :target_device, GreenManTavern.Rack.Device

    timestamps()
  end

  @doc false
  def changeset(patch_cable, attrs) do
    patch_cable
    |> cast(attrs, [:source_jack_id, :target_jack_id, :cable_color, :user_id, :source_device_id, :target_device_id])
    |> validate_required([:source_jack_id, :target_jack_id, :user_id, :source_device_id, :target_device_id])
  end
end
