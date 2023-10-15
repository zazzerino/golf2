import * as PIXI from "pixi.js";
import * as TWEEN from "@tweenjs/tween.js";
import { OutlineFilter } from "@pixi/filter-outline";

const GAME_WIDTH = 600;
const GAME_HEIGHT = 600;

const CARD_SVG_WIDTH = 240;
const CARD_SVG_HEIGHT = 336;

const CARD_SCALE = 0.25;
const CARD_WIDTH = CARD_SVG_WIDTH * CARD_SCALE;
const CARD_HEIGHT = CARD_SVG_HEIGHT * CARD_SCALE;

const DECK_X_INIT = GAME_WIDTH / 2;
const DECK_X = GAME_WIDTH / 2 - CARD_WIDTH / 2;
const DECK_Y = GAME_HEIGHT / 2;

const TABLE_CARD_X = GAME_WIDTH / 2 + CARD_WIDTH / 2 + 2;
const TABLE_CARD_Y = GAME_HEIGHT / 2;

const HAND_SIZE = 6;
const DOWN_CARD = "2B";

export class GameContext {
  constructor(container, pushEvent, game) {
    window.GAMECTX = this;
    this.container = container;
    this.pushEvent = pushEvent;
    this.game = game;

    this.stage = new PIXI.Container();

    this.renderer = new PIXI.Renderer({
      width: GAME_WIDTH,
      height: GAME_HEIGHT,
      backgroundColor: 0x2e8b57,
      antialias: true,
    });

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

  // events from server

  onGameStart(game) {
    this.game = game;

    for (const player of this.game.players) {
      this.addHand(player);

      this.tweenHandDeal(player.position)
        .forEach((cardTween, index) => {
          cardTween.start();

          if (index == HAND_SIZE - 1) { // the last card in the hand
            cardTween.onComplete(() => {
              this.tweenDeckStart()
                .onComplete(() => {
                  this.addTableCards();

                  this.tweenTableDeal()
                    .start();
                })
                .start();
            });
          }
        });
    }
  }

  onPlayerJoin(game, _playerId) {
    this.game = game;
  }

  onGameEvent(game, event) {
    this.game = game;

    switch (event.action) {
      case "flip":
        this.onFlip(event);
        break;
    }
  }

  onFlip(event) {
    const index = event.hand_index;
    const player = this.game.players.find(p => p.id === event.player_id);

    const handSprites = this.sprites.hands[player.position];
    const oldSprite = handSprites[index];

    const cardName = player.hand[index]["name"];
    const coord = handCardCoord(player.position, index);

    const newSprite = makeCardSprite(cardName, coord.x, coord.y);
    this.stage.addChild(newSprite)

    this.tweenWiggle(newSprite, coord.x)
      .start();

    for (let i = 0; i < handSprites.length; i++) {
      if (!this.placeIsPlayable(`hand_${i}`)) {
        makeCardUnplayable(handSprites[i]);
      }
    }

    if (this.placeIsPlayable("deck")) {
      makeCardPlayable(this.sprites.deck, this.onDeckClick);
    }

    if (this.placeIsPlayable("table")) {
      makeCardPlayable(this.sprites.tableCards[0], this.onTableClick);
    }

    setTimeout(() => { oldSprite.visible = false }, 200);
  }

  // events from client

  onHandClick(player_id, hand_index) {
    this.pushEvent("hand_click", { player_id, hand_index });
  }

  onDeckClick() {
    console.log("clicked deck");
  }

  onTableClick() {
    console.log("table clicked");
  }

  // deck

  addDeck() {
    const x = deckX(this.game.status);
    const sprite = makeCardSprite(DOWN_CARD, x, DECK_Y);
    sprite.place = "deck";

    if (this.placeIsPlayable("deck")) {
      makeCardPlayable(sprite, this.onDeckClick);
    }

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

    if (this.placeIsPlayable("table")) {
      makeCardPlayable(sprite, this.onTableClick);
    }

    this.sprites.tableCards.push(sprite);
    this.stage.addChild(sprite);
  }

  // player hands

  addHand(player) {
    for (let i = 0; i < player.hand.length; i++) {
      const card = player.hand[i];
      const name = card["face_up?"] ? card.name : DOWN_CARD;

      const coord = handCardCoord(player.position, i);
      const sprite = makeCardSprite(name, coord.x, coord.y, coord.rotation);

      sprite.place = "hand";
      sprite.handIndex = i;

      if (this.placeIsPlayable(`hand_${i}`)) {
        makeCardPlayable(sprite, () => this.onHandClick(player.id, i));
      }

      this.sprites.hands[player.position][i] = sprite;
      this.stage.addChild(sprite);
    }
  }

  // tweens

  tweenDeckFromTop() {
    const sprite = this.sprites.deck;
    const toY = sprite.y;

    const fromY = -CARD_HEIGHT / 2;
    sprite.y = fromY;

    return new TWEEN.Tween(this.sprites.deck)
      .to({ y: toY }, 1000)
      .easing(TWEEN.Easing.Quadratic.Out)
  }

  tweenDeckStart() {
    return new TWEEN.Tween(this.sprites.deck)
      .to({ x: DECK_X }, 200)
      .easing(TWEEN.Easing.Quadratic.Out)
  }

  tweenTableDeal() {
    const deck = this.sprites.deck;
    const sprite = this.sprites.tableCards[0];

    const toX = sprite.x;
    const toY = sprite.y;

    const fromX = deck.x;
    const fromY = deck.y;

    sprite.x = fromX;
    sprite.y = fromY;

    return new TWEEN.Tween(sprite)
      .to({ x: toX, y: toY }, 400)
      .easing(TWEEN.Easing.Quadratic.Out);
  }

  tweenHandDeal(position) {
    const sprites = this.sprites.hands[position];
    const cardTweens = [];

    for (let i = sprites.length - 1; i >= 0; i--) {
      const sprite = sprites[i];

      const toX = sprite.x;
      const toY = sprite.y;

      sprite.x = DECK_X_INIT;
      sprite.y = DECK_Y;

      const tween = new TWEEN.Tween(sprite)
        .to({ x: toX, y: toY }, 800)
        .easing(TWEEN.Easing.Cubic.InOut)
        .delay((HAND_SIZE - 1 - i) * 150);

      cardTweens.push(tween);
    }

    return cardTweens;
  }

  tweenWiggle(sprite, toX, distancePx = 2, repeats = 2) {
    const tweenReturn = new TWEEN.Tween(sprite)
      .to({ x: toX }, 70)
      .easing(TWEEN.Easing.Quadratic.Out)

    sprite.x = toX - distancePx;

    return new TWEEN.Tween(sprite)
      .to({ x: toX + distancePx }, 140)
      .easing(TWEEN.Easing.Quintic.InOut)
      .repeat(repeats)
      .yoyo(true)
      .chain(tweenReturn)
  }

  placeIsPlayable(cardPlace) {
    return this.game.playable_cards.includes(cardPlace);
  }
}

// sprite helpers

function makeCardSprite(cardName, x = 0, y = 0, rotation = 0) {
  const path = `/images/cards/${cardName}.svg`;
  const sprite = PIXI.Sprite.from(path);

  sprite.cardName = cardName;
  sprite.scale.set(CARD_SCALE, CARD_SCALE);
  sprite.anchor.set(0.5);

  sprite.x = x;
  sprite.y = y;
  sprite.rotation = rotation;

  return sprite;
}

function makeCardPlayable(sprite, callback) {
  sprite.eventMode = "static";
  sprite.cursor = "pointer";
  sprite.filters = [new OutlineFilter(2, 0xff00ff)];
  sprite.on("pointerdown", event => callback(event.currentTarget));
}

function makeCardUnplayable(sprite) {
  sprite.eventMode = "none";
  sprite.cursor = "none";
  sprite.filters = [];
  sprite.on("pointerdown", () => null);
}

// sprite coords

function deckX(gameStatus) {
  return gameStatus == "init" ? DECK_X_INIT : DECK_X;
}

function handRotation(position) {
  return position == "left" || position === "right"
    ? toRadians(90)
    : 0;
}

function handCardCoord(position, index, xPadding = 3, yPadding = 10) {
  let x = 0, y = 0;

  if (position === "bottom") {
    switch (index) {
      case 0:
        x = GAME_WIDTH / 2 - CARD_WIDTH - xPadding;
        y = GAME_HEIGHT - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        break;

      case 1:
        x = GAME_WIDTH / 2;
        y = GAME_HEIGHT - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        break;

      case 2:
        x = GAME_WIDTH / 2 + CARD_WIDTH + xPadding;
        y = GAME_HEIGHT - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        break;

      case 3:
        x = GAME_WIDTH / 2 - CARD_WIDTH - xPadding;
        y = GAME_HEIGHT - CARD_HEIGHT / 2 - yPadding;
        break;

      case 4:
        x = GAME_WIDTH / 2;
        y = GAME_HEIGHT - CARD_HEIGHT / 2 - yPadding;
        break;

      case 5:
        x = GAME_WIDTH / 2 + CARD_WIDTH + xPadding;
        y = GAME_HEIGHT - CARD_HEIGHT / 2 - yPadding;
        break;
    }
  } else if (position === "top") {
    switch (index) {
      case 0:
        x = GAME_WIDTH / 2 + CARD_WIDTH + xPadding;
        y = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        break;

      case 1:
        x = GAME_WIDTH / 2;
        y = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        break;

      case 2:
        x = GAME_WIDTH / 2 - CARD_WIDTH - xPadding;
        y = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        break;

      case 3:
        x = GAME_WIDTH / 2 + CARD_WIDTH + xPadding;
        y = CARD_HEIGHT / 2 + yPadding;
        break;

      case 4:
        x = GAME_WIDTH / 2;
        y = CARD_HEIGHT / 2 + yPadding;
        break;

      case 5:
        x = GAME_WIDTH / 2 - CARD_WIDTH - xPadding;
        y = CARD_HEIGHT / 2 + yPadding;
        break;
    }
  } else if (position === "left") {
    switch (index) {
      case 0:
        x = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        y = GAME_HEIGHT / 2 - CARD_WIDTH - xPadding;
        break;

      case 1:
        x = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        y = GAME_HEIGHT / 2;
        break;

      case 2:
        x = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        y = GAME_HEIGHT / 2 + CARD_WIDTH + xPadding;
        break;

      case 3:
        x = CARD_HEIGHT / 2 + yPadding;
        y = GAME_HEIGHT / 2 - CARD_WIDTH - xPadding;
        break;

      case 4:
        x = CARD_HEIGHT / 2 + yPadding;
        y = GAME_HEIGHT / 2;
        break;

      case 5:
        x = CARD_HEIGHT / 2 + yPadding;
        y = GAME_HEIGHT / 2 + CARD_WIDTH + xPadding;
        break;
    }
  } else if (position === "right") {
    switch (index) {
      case 0:
        x = GAME_WIDTH - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        y = GAME_HEIGHT / 2 + CARD_WIDTH + xPadding;
        break;

      case 1:
        x = GAME_WIDTH - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        y = GAME_HEIGHT / 2;
        break;

      case 2:
        x = GAME_WIDTH - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        y = GAME_HEIGHT / 2 - CARD_WIDTH - xPadding;
        break;

      case 3:
        x = GAME_WIDTH - CARD_HEIGHT / 2 - yPadding;
        y = GAME_HEIGHT / 2 + CARD_WIDTH + xPadding;
        break;

      case 4:
        x = GAME_WIDTH - CARD_HEIGHT / 2 - yPadding;
        y = GAME_HEIGHT / 2;
        break;

      case 5:
        x = GAME_WIDTH - CARD_HEIGHT / 2 - yPadding;
        y = GAME_HEIGHT / 2 - CARD_WIDTH - xPadding;
        break;
    }
  }

  const rotation = handRotation(position);
  return { x, y, rotation };
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}

function randRange(min, max) {
  return Math.floor(Math.random() * (max - min + 1) + min);
}
