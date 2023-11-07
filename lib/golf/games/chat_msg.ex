defmodule Golf.Games.ChatMsg do
  use Golf.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:player_id, :text, :inserted_at]}
  schema "chat_messages" do
    belongs_to :game, Golf.Games.Game
    belongs_to :player, Golf.Games.Player

    field :text, :string

    timestamps(updated_at: false)
  end

  def changeset(%__MODULE__{} = chat_msg, attrs \\ %{}) do
    chat_msg
    |> cast(attrs, [:game_id, :player_id, :text])
    |> validate_required([:game_id, :player_id, :text])
  end

  def new(game_id, player_id, text) do
    %__MODULE__{
      game_id: game_id,
      player_id: player_id,
      text: text
    }
  end
end
