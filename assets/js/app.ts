// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { LOAD_TEXTURES, GameContext, Game, GameEvent } from "./game";

LOAD_TEXTURES(); // runs in background

type GameMessage = { game: Game };
type GameEventMessage = { game: Game, event: GameEvent };
type PlayerJoinMessage = { game: Game, player_id: number };

const Hooks: { GameCanvas?: any } = {};

let gameContext: GameContext;

// the <div> this connects to is in game_live.html.heex
Hooks.GameCanvas = {
  mounted() {
    this.handleEvent("game_loaded", (data: GameMessage) => {
      console.log("game loaded:", data);

      gameContext = new GameContext(
        data.game,
        this.el,
        this.pushEvent.bind(this)
      );
    });

    this.handleEvent("game_started", (data: GameMessage) => {
      console.log("game started:", data);
      gameContext.onGameStart(data.game);
    });

    this.handleEvent("game_event", (data: GameEventMessage) => {
      console.log("game event:", data);
      gameContext.onGameEvent(data.game, data.event);
    });

    this.handleEvent("player_joined", (data: PlayerJoinMessage) => {
      console.log("player joined:", data)
      gameContext.onPlayerJoin(data.game, data.player_id);
    });
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks: Hooks });

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", _ => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _ => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
// window.liveSocket = liveSocket;

// const GAME_URL_REGEX = /\/games\/\d+/;