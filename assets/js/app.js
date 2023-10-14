// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { GameContext } from "./game";

let Hooks = {};

// matches a path like "/games/12"
const GAME_URL_REGEX = /\/games\/(\d+)/;

// selects the elem we'll append the game canvas to
const GAME_CONTAINER_SELECTOR = "#game-container";

// if we're on a game page, draw the game and setup the GameContainer
if (location.pathname.match(GAME_URL_REGEX)) {
  const container = document.querySelector(GAME_CONTAINER_SELECTOR);
  let GameCtx;

  // the <div> this connects to is in `game_live.html.heex`
  Hooks.GameContainer = {
    mounted() {
      this.handleEvent("game_loaded", data => {
        console.log("game loaded: ", data);

        GameCtx = new GameContext(
          container,
          this.pushEvent.bind(this),
          data.game
        );

        if (data.game.status === "init") {
          GameCtx.tweenDeckFromTop()
            .start();
        }
      });

      this.handleEvent("game_started", data => {
        console.log("game started: ", data);
        GameCtx.onGameStart(data.game, data.players, data.playable_cards);
      });

      this.handleEvent("player_joined", data => {
        console.log("player joined: ", data);
        GameCtx.onPlayerJoin(data.game, data.player_id);
      });

      this.handleEvent("game_event", data => {
        console.log("game event: ", data);
        GameCtx.onGameEvent(data.game, data.event);
      });
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
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
