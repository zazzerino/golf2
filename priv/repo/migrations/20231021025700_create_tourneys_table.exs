defmodule Golf.Repo.Migrations.CreateTourneysTable do
  use Ecto.Migration

  def change do
    create table("tourneys") do
      add :host_id, references("users")
      add :num_rounds, :integer

      timestamps()
    end

    alter table("games") do
      add :tourney_id, references("tourneys")
    end
  end
end
