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

    this.sprites = {
      deck: null,
      tableCards: [],
      heldCard: null,
      hands: { bottom: [], left: [], top: [], right: [] },
    };

    this.addSprites();

    this.container = document.querySelector(containerSelector);
    this.container.appendChild(this.renderer.view);

    this.time = performance.now();
    requestAnimationFrame(time => this.render(time));
  }

  render(time) {
    requestAnimationFrame(time => this.render(time));

    if (this.game.status === "init" && !this.sprites.deck.doneInit) {
      this.animDeckInit();
    }

    TWEEN.update(time);
    this.renderer.render(this.stage);
  }

  onGameStart(game) {
    this.game = game;
    this.animDeckStart();
    this.addTableCards();
  }

  addSprites() {
    this.addDeck();
    this.addTableCards();
  }

  addDeck() {
    this.sprites.deck = makeCardSprite(DECK_NAME, deckX(this.game.status), DECK_Y);
    this.stage.addChild(this.sprites.deck);
  }

  animDeckInit() {
    this.sprites.deck.y = CARD_HEIGHT / 2;
    this.sprites.deck.tweenInit = new TWEEN.Tween(this.sprites.deck);
    this.sprites.deck.tweenInit.to({ y: DECK_Y }, 500);
    this.sprites.deck.tweenInit.easing(TWEEN.Easing.Bounce.Out);
    this.sprites.deck.tweenInit.onComplete(() => this.sprites.deck.doneInit = true);
    this.sprites.deck.tweenInit.start();
  }

  animDeckStart() {
    this.sprites.deck.tweenStart = new TWEEN.Tween(this.sprites.deck);
    this.sprites.deck.tweenStart.to({ x: deckX(this.game.status) }, 500);
    this.sprites.deck.tweenStart.easing(TWEEN.Easing.Quadratic.Out);
    this.sprites.deck.tweenStart.start();
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
