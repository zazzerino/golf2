const GAME_WIDTH = 600;
const GAME_HEIGHT = 600;

const CARD_SVG_WIDTH = 240;
const CARD_SVG_HEIGHT = 336;
const CARD_SCALE = 0.25;

const GAME_URL_REGEX = /\/games\/(\d+)/;

const onGamePage = location.pathname.match(GAME_URL_REGEX);

if (onGamePage) {
  const gameCanvas = document.querySelector("#game-canvas");

  const app = new PIXI.Application({
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
    backgroundColor: 0x2e8b57,
    // antialias: true,
  });

  const sprites = {
    deck: null,
    tableCards: [],
    heldCard: null,
    hands: {bottom: null, left: null, top: null, right: null},
  }

  draw(app.stage);
  gameCanvas.appendChild(app.view);
}

function draw(stage) {
  const deckSprite = makeCardSprite("2B", GAME_WIDTH / 2, GAME_HEIGHT / 2);
  stage.addChild(deckSprite);
}

function cardPath(cardName) {
  return `/images/cards/${cardName}.svg`
}

function makeCardSprite(cardName, x = 0, y = 0) {
  const path = cardPath(cardName);
  const sprite = PIXI.Sprite.from(path);

  sprite.scale.set(CARD_SCALE, CARD_SCALE);
  sprite.anchor.set(0.5);
  sprite.x = x;
  sprite.y = y;
  sprite.cardName = cardName;

  return sprite;
}