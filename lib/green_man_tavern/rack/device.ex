defmodule GreenManTavern.Rack.Device do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "devices" do
    field :name, :string
    field :position_index, :integer
    field :settings, :map, default: %{inputs: [], outputs: []}

    belongs_to :user, GreenManTavern.Accounts.User, type: :id
    belongs_to :project, GreenManTavern.Projects.Project, type: :id
    belongs_to :user_plant, GreenManTavern.PlantingGuide.UserPlant, type: :id

    belongs_to :parent_device, GreenManTavern.Rack.Device
    has_many :child_devices, GreenManTavern.Rack.Device, foreign_key: :parent_device_id

    has_many :source_cables, GreenManTavern.Rack.PatchCable, foreign_key: :source_device_id
    has_many :target_cables, GreenManTavern.Rack.PatchCable, foreign_key: :target_device_id

    timestamps()
  end

  def changeset(device, attrs) do
    changeset = 
      device
      |> cast(attrs, [:name, :position_index, :settings, :user_id, :project_id, :user_plant_id, :parent_device_id])
    
    # project_id is optional for composite systems
    is_composite = get_field(changeset, :settings) |> Map.get("is_composite", false)
    
    if is_composite do
      changeset |> validate_required([:name, :position_index, :user_id])
    else
      changeset |> validate_required([:name, :position_index, :user_id, :project_id])
    end
  end
end
