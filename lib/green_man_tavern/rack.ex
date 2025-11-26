defmodule GreenManTavern.Rack do
  @moduledoc """
  The Rack context.
  """

  import Ecto.Query, warn: false
  alias GreenManTavern.Repo

  alias GreenManTavern.Rack.Device
  alias GreenManTavern.Rack.PatchCable

  @doc """
  Returns the list of devices.

  ## Examples

      iex> list_devices()
      [%Device{}, ...]

  """
  def list_devices do
    Repo.all(Device)
  end

  @doc """
  Gets a single device.

  Raises `Ecto.NoResultsError` if the Device does not exist.

  ## Examples

      iex> get_device!(123)
      %Device{}

      iex> get_device!(456)
      ** (Ecto.NoResultsError)

  """
  def get_device!(id), do: Repo.get!(Device, id)

  @doc """
  Creates a device.

  ## Examples

      iex> create_device(%{field: value})
      {:ok, %Device{}}

      iex> create_device(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_device(attrs \\ %{}) do
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a device.

  ## Examples

      iex> update_device(device, %{field: new_value})
      {:ok, %Device{}}

      iex> update_device(device, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_device(%Device{} = device, attrs) do
    device
    |> Device.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a device.

  ## Examples

      iex> delete_device(device)
      {:ok, %Device{}}

      iex> delete_device(device)
      {:error, %Ecto.Changeset{}}

  """
  def delete_device(%Device{} = device) do
    Repo.delete(device)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking device changes.

  ## Examples

      iex> change_device(device)
      %Ecto.Changeset{data: %Device{}}

  """
  def change_device(%Device{} = device, attrs \\ %{}) do
    Device.changeset(device, attrs)
  end

  @doc """
  Returns the list of patch_cables.

  ## Examples

      iex> list_patch_cables()
      [%PatchCable{}, ...]

  """
  def list_patch_cables do
    Repo.all(PatchCable)
  end

  @doc """
  Gets a single patch_cable.

  Raises `Ecto.NoResultsError` if the Patch cable does not exist.

  ## Examples

      iex> get_patch_cable!(123)
      %PatchCable{}

      iex> get_patch_cable!(456)
      ** (Ecto.NoResultsError)

  """
  def get_patch_cable!(id), do: Repo.get!(PatchCable, id)

  @doc """
  Creates a patch_cable.

  ## Examples

      iex> create_patch_cable(%{field: value})
      {:ok, %PatchCable{}}

      iex> create_patch_cable(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_patch_cable(attrs \\ %{}) do
    %PatchCable{}
    |> PatchCable.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a patch_cable.

  ## Examples

      iex> update_patch_cable(patch_cable, %{field: new_value})
      {:ok, %PatchCable{}}

      iex> update_patch_cable(patch_cable, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_patch_cable(%PatchCable{} = patch_cable, attrs) do
    patch_cable
    |> PatchCable.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a patch_cable.

  ## Examples

      iex> delete_patch_cable(patch_cable)
      {:ok, %PatchCable{}}

      iex> delete_patch_cable(patch_cable)
      {:error, %Ecto.Changeset{}}

  """
  def delete_patch_cable(%PatchCable{} = patch_cable) do
    Repo.delete(patch_cable)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking patch_cable changes.

  ## Examples

      iex> change_patch_cable(patch_cable)
      %Ecto.Changeset{data: %PatchCable{}}

  """
  def change_patch_cable(%PatchCable{} = patch_cable, attrs \\ %{}) do
    PatchCable.changeset(patch_cable, attrs)
  end
end
