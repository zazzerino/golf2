defmodule GolfWeb.TourneyOptsLive do
  use GolfWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="tourney-opts">
      <h2>Tourney Opts</h2>

      <form phx-submit="start_tourney">
        <label for="num_rounds">Number of rounds</label>
        <input name="num_rounds" type="number" min="1" value="4" class="nes-input" />
        <button type="submit" class="nes-btn is-primary" style="margin-top:1rem">
          Start Tourney
        </button>
      </form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Tourney Opts")}
  end

  @impl true
  def handle_event("start_tourney", %{"num_rounds" => num_rounds}, socket) do
    user = socket.assigns.user
    {num_rounds, _} = Integer.parse(num_rounds)
    {:ok, tourney} = Golf.GamesDb.create_tourney(user, num_rounds: num_rounds)
    game = List.first(tourney.games)
    {:noreply, push_navigate(socket, to: ~p"/games/#{game.id}")}
  end
end
