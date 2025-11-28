defmodule GreenManTavern.Rack.Device do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "devices" do
    field :name, :string
    field :position_index, :integer
    field :settings, :map, default: %{"inputs" => [], "outputs" => []}
    field :position_x, :float, default: 0.0
    field :position_y, :float, default: 0.0

    belongs_to :user, GreenManTavern.Accounts.User, type: :id
    belongs_to :project, GreenManTavern.Projects.Project, type: :id
    belongs_to :user_plant, GreenManTavern.PlantingGuide.UserPlant, type: :id

    has_many :source_cables, GreenManTavern.Rack.PatchCable, foreign_key: :source_device_id
    has_many :target_cables, GreenManTavern.Rack.PatchCable, foreign_key: :target_device_id

    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:name, :position_index, :settings, :user_id, :project_id, :user_plant_id])
    |> validate_required([:name, :position_index, :user_id, :project_id])
  end
end

