defmodule GreenManTavern.RackTest do
  use GreenManTavern.DataCase

  alias GreenManTavern.Rack

  describe "devices" do
    alias GreenManTavern.Rack.Device

    import GreenManTavern.RackFixtures

    @invalid_attrs %{name: nil, position_index: nil}

    setup do
      user = GreenManTavern.Repo.insert!(%GreenManTavern.Accounts.User{
        email: "test@example.com",
        hashed_password: "password",
        confirmed_at: NaiveDateTime.utc_now()
      })

      project = GreenManTavern.Repo.insert!(%GreenManTavern.Projects.Project{
        name: "Test Project",
        category: "food"
      })

      {:ok, user: user, project: project}
    end

    test "list_devices/0 returns all devices", %{user: user, project: project} do
      device = device_fixture(user, project)
      assert Rack.list_devices() == [device]
    end

    test "get_device!/1 returns the device with given id", %{user: user, project: project} do
      device = device_fixture(user, project)
      assert Rack.get_device!(device.id) == device
    end

    test "create_device/1 with valid data creates a device", %{user: user, project: project} do
      valid_attrs = %{name: "some name", position_index: 42, user_id: user.id, project_id: project.id}

      assert {:ok, %Device{} = device} = Rack.create_device(valid_attrs)
      assert device.name == "some name"
      assert device.position_index == 42
    end

    test "create_device/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rack.create_device(@invalid_attrs)
    end

    test "update_device/2 with valid data updates the device", %{user: user, project: project} do
      device = device_fixture(user, project)
      update_attrs = %{name: "some updated name", position_index: 43}

      assert {:ok, %Device{} = device} = Rack.update_device(device, update_attrs)
      assert device.name == "some updated name"
      assert device.position_index == 43
    end

    test "update_device/2 with invalid data returns error changeset", %{user: user, project: project} do
      device = device_fixture(user, project)
      assert {:error, %Ecto.Changeset{}} = Rack.update_device(device, @invalid_attrs)
      assert device == Rack.get_device!(device.id)
    end

    test "delete_device/1 deletes the device", %{user: user, project: project} do
      device = device_fixture(user, project)
      assert {:ok, %Device{}} = Rack.delete_device(device)
      assert_raise Ecto.NoResultsError, fn -> Rack.get_device!(device.id) end
    end

    test "change_device/1 returns a device changeset", %{user: user, project: project} do
      device = device_fixture(user, project)
      assert %Ecto.Changeset{} = Rack.change_device(device)
    end
  end

  describe "patch_cables" do
    alias GreenManTavern.Rack.PatchCable

    import GreenManTavern.RackFixtures

    @invalid_attrs %{source_jack_id: nil, target_jack_id: nil}

    setup do
      user = GreenManTavern.Repo.insert!(%GreenManTavern.Accounts.User{
        email: "test_cables@example.com",
        hashed_password: "password",
        confirmed_at: NaiveDateTime.utc_now()
      })

      project = GreenManTavern.Repo.insert!(%GreenManTavern.Projects.Project{
        name: "Test Project Cables",
        category: "food"
      })

      source_device = device_fixture(user, project, %{name: "Source Device"})
      target_device = device_fixture(user, project, %{name: "Target Device"})

      {:ok, user: user, source_device: source_device, target_device: target_device}
    end

    test "list_patch_cables/0 returns all patch_cables", %{user: user, source_device: source_device, target_device: target_device} do
      patch_cable = patch_cable_fixture(user, source_device, target_device)
      assert Rack.list_patch_cables() == [patch_cable]
    end

    test "get_patch_cable!/1 returns the patch_cable with given id", %{user: user, source_device: source_device, target_device: target_device} do
      patch_cable = patch_cable_fixture(user, source_device, target_device)
      assert Rack.get_patch_cable!(patch_cable.id) == patch_cable
    end

    test "create_patch_cable/1 with valid data creates a patch_cable", %{user: user, source_device: source_device, target_device: target_device} do
      valid_attrs = %{source_jack_id: "some source_jack_id", target_jack_id: "some target_jack_id", cable_color: "some cable_color", user_id: user.id, source_device_id: source_device.id, target_device_id: target_device.id}

      assert {:ok, %PatchCable{} = patch_cable} = Rack.create_patch_cable(valid_attrs)
      assert patch_cable.source_jack_id == "some source_jack_id"
      assert patch_cable.target_jack_id == "some target_jack_id"
      assert patch_cable.cable_color == "some cable_color"
    end

    test "create_patch_cable/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rack.create_patch_cable(@invalid_attrs)
    end

    test "update_patch_cable/2 with valid data updates the patch_cable", %{user: user, source_device: source_device, target_device: target_device} do
      patch_cable = patch_cable_fixture(user, source_device, target_device)
      update_attrs = %{source_jack_id: "some updated source_jack_id", target_jack_id: "some updated target_jack_id", cable_color: "some updated cable_color"}

      assert {:ok, %PatchCable{} = patch_cable} = Rack.update_patch_cable(patch_cable, update_attrs)
      assert patch_cable.source_jack_id == "some updated source_jack_id"
      assert patch_cable.target_jack_id == "some updated target_jack_id"
      assert patch_cable.cable_color == "some updated cable_color"
    end

    test "update_patch_cable/2 with invalid data returns error changeset", %{user: user, source_device: source_device, target_device: target_device} do
      patch_cable = patch_cable_fixture(user, source_device, target_device)
      assert {:error, %Ecto.Changeset{}} = Rack.update_patch_cable(patch_cable, @invalid_attrs)
      assert patch_cable == Rack.get_patch_cable!(patch_cable.id)
    end

    test "delete_patch_cable/1 deletes the patch_cable", %{user: user, source_device: source_device, target_device: target_device} do
      patch_cable = patch_cable_fixture(user, source_device, target_device)
      assert {:ok, %PatchCable{}} = Rack.delete_patch_cable(patch_cable)
      assert_raise Ecto.NoResultsError, fn -> Rack.get_patch_cable!(patch_cable.id) end
    end

    test "change_patch_cable/1 returns a patch_cable changeset", %{user: user, source_device: source_device, target_device: target_device} do
      patch_cable = patch_cable_fixture(user, source_device, target_device)
      assert %Ecto.Changeset{} = Rack.change_patch_cable(patch_cable)
    end
  end

  defp device_fixture(user, project, attrs \\ %{}) do
    {:ok, device} =
      attrs
      |> Enum.into(%{
        name: "some name",
        position_index: 42,
        user_id: user.id,
        project_id: project.id
      })
      |> GreenManTavern.Rack.create_device()

    device
  end

  defp patch_cable_fixture(user, source_device, target_device, attrs \\ %{}) do
    {:ok, patch_cable} =
      attrs
      |> Enum.into(%{
        source_jack_id: "some source_jack_id",
        target_jack_id: "some target_jack_id",
        cable_color: "some cable_color",
        user_id: user.id,
        source_device_id: source_device.id,
        target_device_id: target_device.id
      })
      |> GreenManTavern.Rack.create_patch_cable()

    patch_cable
  end
end
