import { PIXI } from "../vendor/pixi";

const GAME_WIDTH = 600;
const GAME_HEIGHT = 600;

const CARD_SVG_WIDTH = 240;
const CARD_SVG_HEIGHT = 336;
const CARD_SCALE = 0.25;

const CARD_WIDTH = CARD_SVG_WIDTH * CARD_SCALE;
const CARD_HEIGHT = CARD_SVG_HEIGHT * CARD_SCALE;

const DECK_NAME = "2B";
const DECK_Y = GAME_HEIGHT / 2;

export function makeGameContext(game) {
  const pixi = new PIXI.Application({
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
    backgroundColor: 0x2e8b57,
    // antialias: true,
  });

  const sprites = {
    deck: null,
    tableCards: null,
    heldCard: null,
    hands: { bottom: null, left: null, top: null, right: null },
  }

  return { game, pixi, sprites }
}

export function drawGame(game, stage, sprites) {
  drawDeck(game, stage, sprites);
}

export function onGameStart(game, stage, sprites) {

}

function drawDeck(game, stage, sprites) {
  const prevSprite = sprites.deck;
  const sprite = makeCardSprite(DECK_NAME, deckX(game.status), DECK_Y);

  if (game.status === "init") {
    sprite.y = -CARD_HEIGHT / 2;

    const ticker = new PIXI.Ticker();
    ticker.add(delta => animateInitDeck(sprite, delta, ticker));
    ticker.start();
  }

  stage.addChild(sprite);
  sprites.deck = sprite;

  if (prevSprite) {
    prevSprite.visible = false;
  }
}

function deckX(gameStatus) {
  return gameStatus == "init"
    ? GAME_WIDTH / 2
    : GAME_WIDTH / 2 - CARD_WIDTH / 2;
}

function animateInitDeck(sprite, delta, ticker) {
  if (sprite.y < GAME_HEIGHT / 2) {
    sprite.y += delta * 8;
  } else {
    sprite.y = DECK_Y;
    ticker.destroy();
  }
}

function makeCardSprite(cardName, x = 0, y = 0) {
  const path = `/images/cards/${cardName}.svg`;
  const sprite = PIXI.Sprite.from(path);

  sprite.scale.set(CARD_SCALE, CARD_SCALE);
  sprite.anchor.set(0.5);
  sprite.x = x;
  sprite.y = y;
  sprite.cardName = cardName;

  return sprite;
}
