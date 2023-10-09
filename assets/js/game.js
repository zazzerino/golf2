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

export class GameContext {
  constructor(game) {
    this.game = game;
    this.container = document.querySelector("#game-container");

    this.sprites = {
      deck: null,
      tableCards: null,
      heldCard: null,
      hands: { bottom: null, left: null, top: null, right: null },
    }

    this.renderer = new PIXI.Renderer({
      width: GAME_WIDTH,
      height: GAME_HEIGHT,
      backgroundColor: 0x2e8b57
    });

    this.container.appendChild(this.renderer.view);
    this.stage = new PIXI.Container();
    this.addSprites();

    this.oldTime = performance.now();
    requestAnimationFrame(() => this.animate());
  }

  animate() {
    const newTime = performance.now();
    let deltaTime = newTime - this.oldTime;
    this.oldTime = newTime;

    if (deltaTime < 0) deltaTime = 0;
    if (deltaTime > 1000) deltaTime = 1000;

    const delta = deltaTime * 60 / 1000;

    // animate deck init
    if (this.game.status === "init"
      && !this.sprites.deck.isAnimInit
      && !this.sprites.deck.doneAnimInit) {
      this.sprites.deck.y = -CARD_HEIGHT;
      this.sprites.deck.isAnimInit = true;
    }

    if (this.sprites.deck.isAnimInit) {
      this.animDeckInitStep(delta);
    }

    this.renderer.render(this.stage);
    requestAnimationFrame(() => this.animate());
  }

  onGameStart(game) {
    this.game = game;
    this.sprites.deck.x = deckX(this.game.status);
  }

  addSprites() {
    this.addDeck();
  }

  addDeck() {
    const sprite = makeCardSprite(DECK_NAME, deckX(this.game.status), DECK_Y);
    this.stage.addChild(sprite);
    this.sprites.deck = sprite;
  }

  animDeckInitStep(delta) {
    if (this.sprites.deck.y < DECK_Y) {
      this.sprites.deck.y += 6 * delta; 
    } else {
      this.sprites.deck.y = DECK_Y;
      this.sprites.deck.isAnimInit = false;
      this.sprites.deck.doneAnimInit = true;
    }
  }
}

function deckX(gameStatus) {
  return gameStatus == "init"
    ? GAME_WIDTH / 2
    : GAME_WIDTH / 2 - CARD_WIDTH / 2;
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
