defmodule Golf.Repo.Migrations.CreateGameEventsTable do
  use Ecto.Migration

  def change do
    create table("game_events") do
      add :game_id, references("games")
      add :player_id, references("players")

      add :action, :string
      add :hand_index, :integer

      timestamps(updated_at: false)
    end
  end
end
