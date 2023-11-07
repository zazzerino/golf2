defmodule Golf.Games.Tourney do
  use Golf.Schema
  import Ecto.Changeset

  schema "tourneys" do
    belongs_to :host, Golf.Users.User
    has_many :games, Golf.Games.Game

    field :num_rounds, :integer
    field :host_username, :string, virtual: true

    timestamps()
  end

  def changeset(%__MODULE__{} = tourney, attrs \\ %{}) do
    tourney
    |> cast(attrs, [:host_id, :num_rounds])
    |> validate_required([:host_id, :num_rounds])
  end
end
