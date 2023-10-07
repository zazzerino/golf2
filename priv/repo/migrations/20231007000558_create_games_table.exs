defmodule Golf.Repo.Migrations.CreateGamesTable do
  use Ecto.Migration

  def change do
    create table("games") do
      add :status, :string
      add :turn, :integer
      add :deck, {:array, :string}
      add :table_cards, {:array, :string}
      add :deleted?, :boolean

      timestamps()
    end
  end
end
