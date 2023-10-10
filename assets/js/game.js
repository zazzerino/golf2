import { PIXI } from "../vendor/pixi";
import * as TWEEN from "../vendor/tween.umd";

const GAME_WIDTH = 600;
const GAME_HEIGHT = 600;

const CARD_SVG_WIDTH = 240;
const CARD_SVG_HEIGHT = 336;
const CARD_SCALE = 0.25;

const CARD_WIDTH = CARD_SVG_WIDTH * CARD_SCALE;
const CARD_HEIGHT = CARD_SVG_HEIGHT * CARD_SCALE;

const DECK_NAME = "2B";
const DECK_Y = GAME_HEIGHT / 2;

const TABLE_CARD_X = GAME_WIDTH / 2 + CARD_WIDTH / 2 + 2;
const TABLE_CARD_Y = GAME_HEIGHT / 2;

export class GameContext {
  constructor(game, containerSelector) {
    this.game = game;
    this.stage = new PIXI.Container();

    this.renderer = new PIXI.Renderer({
      width: GAME_WIDTH,
      height: GAME_HEIGHT,
      backgroundColor: 0x2e8b57
    });

    this.container = document.querySelector(containerSelector);
    this.container.appendChild(this.renderer.view);

    this.sprites = {
      deck: null,
      tableCards: [],
      heldCard: null,
      hands: { bottom: [], left: [], top: [], right: [] },
    };
    window.sprites = this.sprites;

    this.addSprites();
    requestAnimationFrame(time => this.drawLoop(time));
  }

  drawLoop(time) {
    requestAnimationFrame(time => this.drawLoop(time));

    this.updateDeck();

    TWEEN.update(time);
    this.renderer.render(this.stage);
  }

  onGameStart(game) {
    this.game = game;
    this.animDeckStart();
  }

  addSprites() {
    this.addDeck();

    if (this.game.status !== "init") {
      this.addTableCards();
    }
  }

  addDeck() {
    const x = deckX(this.game.status);
    this.sprites.deck = makeCardSprite(DECK_NAME, x, DECK_Y);
    this.stage.addChild(this.sprites.deck);
  }

  updateDeck() {
    if (this.game.status === "init"
      && !this.sprites.deck.isAnimInit
      && !this.sprites.deck.doneAnimInit) {
      this.animDeckInit();
    }
  }

  animDeckInit() {
    this.sprites.deck.isAnimInit = true;
    this.sprites.deck.y = -CARD_HEIGHT / 2;

    this.sprites.deck.tweenInit = new TWEEN.Tween(this.sprites.deck)
      .to({ y: DECK_Y }, 1250)
      .easing(TWEEN.Easing.Quadratic.Out)
      .onComplete(() => {
        this.sprites.deck.isAnimInit = false;
        this.sprites.deck.doneAnimInit = true;
      })
      .start();
  }

  animDeckStart() {
    const newX = deckX(this.game.status);

    this.sprites.deck.tweenStart = new TWEEN.Tween(this.sprites.deck)
      .to({ x: newX}, 250)
      .easing(TWEEN.Easing.Quadratic.Out)
      .onComplete(() => {
        this.addTableCards();
        this.animTableStart();
      })
      .start();
  }

  addTableCard(name) {
    const sprite = makeCardSprite(name, TABLE_CARD_X, TABLE_CARD_Y);
    this.sprites.tableCards.push(sprite)
    this.stage.addChild(sprite);
  }

  addTableCards() {
    const card0 = this.game.table_cards[0];
    const card1 = this.game.table_cards[1];

    if (card0) this.addTableCard(card0);
    if (card1) this.addTableCard(card1);
  }

  animTableStart() {
    const sprite = this.sprites.tableCards[0];
    sprite.x = this.sprites.deck.x;
    sprite.y = this.sprites.deck.y;

    sprite.tweenStart = new TWEEN.Tween(sprite)
      .to({x: TABLE_CARD_X, y: TABLE_CARD_Y}, 500)
      .start();
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
