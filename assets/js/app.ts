// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { GameContext, Game, GameEvent } from "./game";

type GameMessage = { game: Game };
type GameEventMessage = { game: Game, event: GameEvent };
type PlayerJoinMessage = { game: Game, player_id: number };

// matches a path like "/games/42"
const GAME_URL_REGEX = /\/games\/\d+/;
const GAME_CANVAS_SELECTOR = "#game-canvas";

let hooks: { GameCanvas?: any } = {};

// if we're on a game page, draw the game and setup the GameCanvas
if (location.pathname.match(GAME_URL_REGEX)) {
  let gameContext: GameContext;

  // the <div> this connects to is in game_live.html.heex
  hooks.GameCanvas = {
    mounted() {
      this.handleEvent("game_loaded", (data: GameMessage) => {
        console.log("game loaded:", data);

        const parent = document.querySelector<HTMLElement>(GAME_CANVAS_SELECTOR);
        if (parent == null) throw new Error(`couldn't find ${GAME_CANVAS_SELECTOR}`);

        const pushEvent = this.pushEvent.bind(this);
        gameContext = new GameContext(data.game, parent, pushEvent);
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
        gameContext.onPlayerJoin(data.game, data.player_id);
      });
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks: hooks });

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
