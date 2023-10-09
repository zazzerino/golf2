const GAME_WIDTH = 600;
const GAME_HEIGHT = 600;

const CARD_SVG_WIDTH = 240;
const CARD_SVG_HEIGHT = 336;

const CARD_SCALE = 0.25;
const DECK_NAME = "2B";

export function makeGameObjects(container) {
  const sprites = {
    deck: null,
    tableCards: null,
    heldCard: null,
    hands: {bottom: null, left: null, top: null, right: null},
  }

  const pixi = new PIXI.Application({
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
    backgroundColor: 0x2e8b57,
    // antialias: true,
  });

  drawGame(pixi.stage, sprites);
  container.appendChild(pixi.view);

  return {container, pixi, sprites}
}

function drawGame(stage, sprites) {
  drawDeck(stage, sprites);
}

function drawDeck(stage, sprites) {
  const prevSprite = sprites.deck;
  const deckSprite = makeCardSprite(DECK_NAME, GAME_WIDTH / 2, GAME_HEIGHT / 2);
  
  stage.addChild(deckSprite);
  sprites.deck = deckSprite;

  if (prevSprite) {
    prevSprite.visible = false;
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