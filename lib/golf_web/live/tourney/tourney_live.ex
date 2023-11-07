defmodule GolfWeb.TourneyLive do
  use GolfWeb, :live_view

  @impl true
  def mount(%{"tourney_id" => tourney_id}, _session, socket) do
    {tourney_id, _} = Integer.parse(tourney_id)

    if connected?(socket) do
      send(self(), {:load_tourney, tourney_id})
    end

    {:ok,
     assign(socket,
       page_title: "Tourney #{tourney_id}",
       tourney_id: tourney_id,
       tourney: nil,
       inserted_at: nil
     )}
  end

  @impl true
  def handle_info({:load_tourney, tourney_id}, socket) do
    tourney = Golf.GamesDb.get_tourney(tourney_id) |> dbg()
    inserted_at = Calendar.strftime(tourney.inserted_at, Golf.inserted_at_format())

    {:noreply, assign(socket, tourney: tourney, inserted_at: inserted_at)}
  end

  @impl true
  def handle_event("game_click", %{"game_id" => game_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end
end
