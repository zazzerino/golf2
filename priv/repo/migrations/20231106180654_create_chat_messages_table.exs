defmodule Golf.Repo.Migrations.CreateChatMessagesTable do
  use Ecto.Migration

  def change do
    create table("chat_messages") do
      add :game_id, references("games")
      add :player_id, references("players")
      add :text, :string
      timestamps(updated_at: false)
    end
  end
end
