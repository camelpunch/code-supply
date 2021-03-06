defmodule Affable.Repo.Migrations.AddMadeAvailableAtToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add(:made_available_at, :utc_datetime, null: true)
    end
  end
end
