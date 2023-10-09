defmodule Golf.Repo.Migrations.CreatePlayersTable do
  use Ecto.Migration

  def change do
    create table("players") do
      add :game_id, references("games")
      add :user_id, references("users")

      add :hand, {:array, :map}
      add :held_card, :string
      add :turn, :integer

      timestamps()
    end
  end
end
