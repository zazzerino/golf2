defmodule Golf.Games.Event do
  use Golf.Schema
  import Ecto.Changeset

  @actions [:take_from_deck, :take_from_table, :swap, :discard, :flip]

  @derive {Jason.Encoder, only: [:game_id, :player_id, :action, :hand_index]}
  schema "events" do
    belongs_to :game, Golf.Games.Game
    belongs_to :player, Golf.Games.Player

    field :action, Ecto.Enum, values: @actions
    field :hand_index, :integer

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:game_id, :player_id, :action, :hand_index])
    |> validate_required([:game_id, :player_id, :action])
  end
end
