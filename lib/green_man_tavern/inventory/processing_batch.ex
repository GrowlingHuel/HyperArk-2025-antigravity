defmodule GreenManTavern.Inventory.ProcessingBatch do
  use Ecto.Schema
  import Ecto.Changeset

  schema "processing_batches" do
    field :process_type, :string
    field :input_items, :map
    field :output_items, :map
    field :started_at, :naive_datetime
    field :complete_at, :naive_datetime
    field :status, :string, default: "in_progress"
    field :metadata, :map

    belongs_to :user, GreenManTavern.Accounts.User
    belongs_to :system, GreenManTavern.Systems.UserSystem

    timestamps()
  end

  @valid_process_types ~w(drying fermenting composting seed_saving freezing)
  @valid_statuses ~w(in_progress complete cancelled failed)

  def changeset(processing_batch, attrs) do
    processing_batch
    |> cast(attrs, [
      :user_id,
      :process_type,
      :system_id,
      :input_items,
      :output_items,
      :started_at,
      :complete_at,
      :status,
      :metadata
    ])
    |> validate_required([:user_id, :process_type, :input_items, :output_items, :complete_at])
    |> validate_inclusion(:process_type, @valid_process_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_complete_after_start()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:system_id)
  end

  defp validate_complete_after_start(changeset) do
    started = get_field(changeset, :started_at) || NaiveDateTime.utc_now()
    complete = get_field(changeset, :complete_at)

    if complete && NaiveDateTime.compare(complete, started) == :lt do
      add_error(changeset, :complete_at, "must be after started_at")
    else
      changeset
    end
  end
end
