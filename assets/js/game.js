const GAME_WIDTH = 600;
const GAME_HEIGHT = 600;

const CARD_SVG_WIDTH = 240;
const CARD_SVG_HEIGHT = 336;
const CARD_SCALE = 0.25;

const gameUrlRegex = /\/games\/(\d+)/;
const onGamePage = location.pathname.match(gameUrlRegex);

if (onGamePage) {
  const container = document.querySelector("#game-container");

  const app = new PIXI.Application({
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
    backgroundColor: 0x2e8b57,
    // antialias: true,
  });

  const sprite = makeCardSprite("AS", 300, 300);
  app.stage.addChild(sprite);

  container.appendChild(app.view);
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