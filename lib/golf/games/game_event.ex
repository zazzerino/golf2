defmodule Golf.Games.GameEvent do
  use Golf.Schema
  import Ecto.Changeset

  @actions [:take_from_deck, :take_from_table, :swap, :discard, :flip]

  @derive {Jason.Encoder, only: [:game_id, :player_id, :action, :hand_index]}
  schema "game_events" do
    belongs_to :game, Golf.Games.Game
    belongs_to :player, Golf.Games.Player

    field :action, Ecto.Enum, values: @actions
    field :hand_index, :integer

    timestamps(updated_at: false)
  end

  def changeset(event, attrs \\ %{}) do
    event
    |> cast(attrs, [:game_id, :player_id, :action, :hand_index])
    |> validate_required([:game_id, :player_id, :action])
  end

  def new(game_id, player_id, action, hand_index \\ nil) do
    %__MODULE__{
      game_id: game_id,
      player_id: player_id,
      action: action,
      hand_index: hand_index
    }
  end
end
