import * as PIXI from "pixi.js";
import * as TWEEN from "@tweenjs/tween.js";
import { OutlineFilter } from "@pixi/filter-outline";

const GAME_WIDTH = 600;
const GAME_HEIGHT = 600;

const DOWN_CARD = "2B";

const CARD_SVG_WIDTH = 240;
const CARD_SVG_HEIGHT = 336;
const CARD_SCALE = 0.25;

const CARD_WIDTH = CARD_SVG_WIDTH * CARD_SCALE;
const CARD_HEIGHT = CARD_SVG_HEIGHT * CARD_SCALE;

const DECK_Y = GAME_HEIGHT / 2;

const TABLE_CARD_X = GAME_WIDTH / 2 + CARD_WIDTH / 2 + 2;
const TABLE_CARD_Y = GAME_HEIGHT / 2;

export class GameContext {
  constructor(game, containerSelector, pushEvent) {
    this.game = game;
    this.pushEvent = pushEvent;
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

    this.addSprites();
    requestAnimationFrame(time => this.drawLoop(time));
  }

  drawLoop(time) {
    requestAnimationFrame(time => this.drawLoop(time));
    TWEEN.update(time);
    this.renderer.render(this.stage);
  }

  addSprites() {
    this.addDeck();

    if (this.game.status !== "init") {
      this.addTableCards();

      for (const player of this.game.players) {
        this.addHand(player);
      }
    }
  }

  // server events

  onGameStart(game) {
    this.game = game;
    this.tweenDeckStart();
    
    for (const player of this.game.players) {
      const hand = this.addHand(player);
      this.tweenHandDeal(hand);
    }
  }

  onPlayerJoin(game, _playerId) {
    this.game = game;
  }

  onGameEvent(game, event) {
    this.game = game;

    switch (event.action) {
      case "flip":
        this.handleFlip(event);
        break;
    }
  }

  handleFlip(event) {
    const player = this.game.players.find(p => p.id === event.player_id);
    const handContainer = this.sprites.hands[player.position];

    const index = event.hand_index;
    const oldSprite = handContainer.children[index];

    const cardName = player.hand[index]["name"];
    const coord = handCardCoord(index);

    const newSprite = makeCardSprite(cardName, coord.x, coord.y);
    handContainer.addChild(newSprite);

    this.tweenFlip(newSprite, coord.x);

    for (let i = 0; i < handContainer.children.length; i++) {
      if (!this.game.playable_cards.includes(`hand_${i}`)) {
        makeCardUnplayable(handContainer.children[i]);
      }
    }

    setTimeout(() => { oldSprite.visible = false }, 100);
  }

  // deck

  addDeck() {
    const x = deckX(this.game.status);
    const sprite = makeCardSprite(DOWN_CARD, x, DECK_Y);
    sprite.place = "deck";

    this.sprites.deck = sprite;
    this.stage.addChild(sprite);
  }

  // table cards

  addTableCards() {
    const card0 = this.game.table_cards[0];
    const card1 = this.game.table_cards[1];

    if (card0) this.addTableCard(card0);
    if (card1) this.addTableCard(card1);
  }

  addTableCard(name) {
    const sprite = makeCardSprite(name, TABLE_CARD_X, TABLE_CARD_Y);
    sprite.place = "table";
    this.sprites.tableCards.push(sprite);
    this.stage.addChild(sprite);
  }

  // player hands

  addHand(player) {
    const container = new PIXI.Container();
    const coord = handCoord(player.position);
    
    container.x = coord.x;
    container.y = coord.y;
    container.angle = coord.angle;
    
    container.pivot.x = container.width / 2;
    container.pivot.y = container.height / 2;

    for (let i = 0; i < player.hand.length; i++) {
      const card = player.hand[i];
      const name = card["face_up?"] ? card.name : DOWN_CARD;

      const sprite = makeCardSprite(name);
      sprite.place = "hand";
      sprite.handIndex = i;

      const coord = handCardCoord(i);
      sprite.x = coord.x;
      sprite.y = coord.y;

      const isPlayable = this.game.playable_cards.includes(`hand_${i}`);

      if (isPlayable) {
        makeCardPlayable(sprite, () => {
          this.pushEvent("hand_card_clicked", {playerId: player.id, handIndex: i});
        });
      }

      container.addChild(sprite);
    }

    this.sprites.hands[player.position] = container;
    this.stage.addChild(container);

    return container;
  }

  // tweens

  tweenDeckFromTop() {
    tweenFromY(this.sprites.deck, -CARD_HEIGHT / 2, 1000)
      .start();
  }

  tweenDeckStart() {
    const newX = deckX(this.game.status);

    new TWEEN.Tween(this.sprites.deck)
      .to({ x: newX }, 200)
      .easing(TWEEN.Easing.Quadratic.Out)
      .onComplete(() => {
        this.addTableCards();
        this.tweenTableDeal();
      })
      .start();
  }

  tweenTableDeal() {
    const sprite = this.sprites.tableCards[0];
    const deck = this.sprites.deck;

    tweenFrom(sprite, deck.x, deck.y, 600)
      .start();
  }

  tweenHandDeal(handContainer) {
    for (const sprite of handContainer.children) {
      tweenFrom(sprite, 0, 0, 1000)
        .delay(randRange(100, 600))
        .start();
    }
  }

  tweenFlip(sprite, finalX)  {
    sprite.x = finalX - 1;

    new TWEEN.Tween(sprite)
      .to({x: finalX + 1}, 150)
      .easing(TWEEN.Easing.Cubic.InOut)
      .repeat(2)
      .yoyo(true)
      .onComplete(() => {
        new TWEEN.Tween(sprite)
          .to({x: finalX}, 65)
          .easing(TWEEN.Easing.Quartic.Out)
          .start();
      })
      .start();
  }
}

// sprite helpers

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

function makeCardPlayable(sprite, callback) {
  sprite.eventMode = "static";
  sprite.cursor = "pointer";
  sprite.filters = [new OutlineFilter(2, 0xff00ff)];
  sprite.on("pointerdown", event => callback(event.currentTarget))
}

function makeCardUnplayable(sprite) {
  sprite.eventMode = "none";
  sprite.cursor = "NONE";
  sprite.filters = [];
  sprite.on("pointerdown", () => null);
}

function tweenFromY(sprite, fromY, duration, easingFn = TWEEN.Easing.Quadratic.Out) {
  const toY = sprite.y;
  sprite.y = fromY;

  return new TWEEN.Tween(sprite)
    .to({ y: toY }, duration)
    .easing(easingFn);
}

function tweenFrom(sprite, fromX, fromY, duration, easingFn = TWEEN.Easing.Quadratic.Out) {
  const toX = sprite.x;
  const toY = sprite.y;

  sprite.x = fromX;
  sprite.y = fromY;

  return new TWEEN.Tween(sprite)
    .to({ x: toX, y: toY }, duration)
    .easing(easingFn);
}

// sprite coords

function deckX(gameStatus) {
  return gameStatus == "init"
    ? GAME_WIDTH / 2
    : GAME_WIDTH / 2 - CARD_WIDTH / 2;
}

function handCoord(position) {
  let x, y, angle;

  switch (position) {
    case "bottom":
      x = GAME_WIDTH / 2;
      y = GAME_HEIGHT - CARD_HEIGHT * 1.4;
      angle = 0;
      break;

    case "top":
      x = GAME_WIDTH / 2;
      y = CARD_HEIGHT * 1.4;
      angle = 180;
      break;

    case "left":
      x = CARD_HEIGHT * 1.4;
      y = GAME_HEIGHT / 2;
      angle = 90;
      break;

    case "right":
      x = GAME_WIDTH - CARD_HEIGHT * 1.4;
      y = GAME_HEIGHT / 2;
      angle = 270;
      break;

    default:
      throw new Error(`position ${position} must be one of: "bottom", "left", "top", "right"`);
  }

  return { x, y, angle };
}

function handCardCoord(handIndex) {
  let x = 0, y = 0;

  switch (handIndex) {
    case 0:
    case 3:
      x = -CARD_WIDTH - 5;
      break;

    case 2:
    case 5:
      x = CARD_WIDTH + 5;
      break;
  }

  switch (handIndex) {
    case 0:
    case 1:
    case 2:
      y = -CARD_HEIGHT / 2 - 2;
      break;

    case 3:
    case 4:
    case 5:
      y = CARD_HEIGHT / 2 + 2;
      break;
  }

  return { x, y };
}

function randRange(min, max) {
  return Math.floor(Math.random() * (max - min + 1) + min);
}
