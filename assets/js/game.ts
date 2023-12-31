import * as PIXI from "pixi.js";
import { Tween, Easing, update as TWEEN_UPDATE } from "@tweenjs/tween.js";
import { OutlineFilter } from "@pixi/filter-outline";

window.addEventListener("phx:chat-message-submitted", _ => {
  const chatMsgInputEl = document.querySelector("#chat-msg-input");
  if (chatMsgInputEl) {
    chatMsgInputEl.innerHTML = "";
  }


});

window.addEventListener("phx:chat-msg-recv", _ => {
  const chatMessagesEl = document.querySelector("#chat-messages");
  if (chatMessagesEl) {
    chatMessagesEl.scrollTo(0, chatMessagesEl.scrollHeight);
  }
});

const GAME_WIDTH = 600;
const GAME_HEIGHT = 600;

const CENTER_X = GAME_WIDTH / 2;
const CENTER_Y = GAME_HEIGHT / 2;

const CARD_IMG_WIDTH = 88;
const CARD_IMG_HEIGHT = 124;

const CARD_SCALE = 0.75;

const CARD_WIDTH = CARD_IMG_WIDTH * CARD_SCALE;
const CARD_HEIGHT = CARD_IMG_HEIGHT * CARD_SCALE;

const DECK_X_INIT = CENTER_X;

const DECK_X = CENTER_X - CARD_WIDTH / 2;
const DECK_Y = CENTER_Y;

/**
The deck png has 5 pixels of cards below the top card.
This offset lets us place cards correctly on top of the deck.
*/
const DECK_Y_OFFSET = -5;

const TABLE_CARD_X = CENTER_X + CARD_WIDTH / 2 + 2;
const TABLE_CARD_Y = CENTER_Y;

const HAND_X_PADDING = 3;
const HAND_Y_PADDING = 10;

const HAND_SIZE = 6;

const DECK_CARD: CardName = "1B";
const DOWN_CARD: CardName = "2B";

const SPRITESHEET = "/images/spritesheets/cards.json";
const HOVER_CURSOR_STYLE = "url('/images/cursor-click.png'),auto";

type CardName = string;

type Position = "bottom" | "left" | "top" | "right";

type Status = "init" | "flip_2" | "take" | "hold" | "flip" | "over";

type Place = "deck" | "table" | "held"
  | "hand_0" | "hand_1" | "hand_2" | "hand_3" | "hand_4" | "hand_5";

type GameAction = "flip" | "take_from_deck" | "take_from_table" | "swap" | "discard";

interface HandCard {
  name: CardName,
  "face_up?": boolean,
}

interface Player {
  id: number,
  user_id: number,
  username: string,
  hand: HandCard[],
  held_card?: CardName,
  turn: number,
  position: Position,
  score: number,
}

export interface Game {
  id: number,
  status: Status,
  turn: number,
  deck: CardName[],
  table_cards: CardName[],
  players: Player[],
  player_id?: number,
  playable_cards: Place[],
}

type Sprites = {
  deck?: PIXI.Sprite,
  held?: PIXI.Sprite,
  tables: PIXI.Sprite[],
  hands: { [p in Position]: PIXI.Sprite[] },
};

export interface GameEvent {
  game_id: number,
  player_id: number,
  action: GameAction,
  hand_index: number | null,
}

type PushEvent = (action: string, data: object) => any;

export function LOAD_TEXTURES() {
  PIXI.Assets.backgroundLoad(SPRITESHEET);
}

export class GameContext {
  game: Game;
  parent: HTMLElement;
  pushEvent: PushEvent; // send events to the server

  textures: { [key: CardName]: PIXI.Texture };
  sprites: Sprites;

  stage: PIXI.Container;
  renderer: PIXI.Renderer;

  constructor(game: Game, parent: HTMLElement, pushEvent: PushEvent) {
    this.game = game;
    this.parent = parent;
    this.pushEvent = pushEvent;

    this.sprites = {
      tables: [],
      hands: { bottom: [], left: [], top: [], right: [] },
    };

    this.stage = new PIXI.Container();

    this.renderer = new PIXI.Renderer({
      width: GAME_WIDTH,
      height: GAME_HEIGHT,
      backgroundColor: "forestgreen",
      antialias: true,
    });

    this.renderer.render(this.stage);
    this.renderer.events.cursorStyles.hover = HOVER_CURSOR_STYLE;

    PIXI.Assets.load([SPRITESHEET])
      .then(assets => {
        this.textures = assets[SPRITESHEET].textures;

        this.parent.appendChild(this.renderer.view as any);
        this.addSprites();
        this.renderer.render(this.stage);

        requestAnimationFrame(time => this.drawLoop(time));
      });
  }

  drawLoop(time: DOMHighResTimeStamp) {
    requestAnimationFrame(time => this.drawLoop(time));
    TWEEN_UPDATE(time);
    this.renderer.render(this.stage);
  }

  // game sprites

  addSprites() {
    this.addDeck();

    if (this.game.status !== "init") {
      this.addTableCards();

      for (const player of this.game.players) {
        this.addHand(player);

        if (player.held_card) {
          this.addHeldCard(player);
        }
      }
    }
  }

  addDeck() {
    const x = deckX(this.game.status);
    const texture = this.textures[DECK_CARD];
    const sprite = makeCardSprite(texture, x, DECK_Y);

    if (this.placeIsPlayable("deck")) {
      makePlayable(sprite, this.onDeckClick.bind(this));
    }

    this.sprites.deck = sprite;
    this.stage.addChild(sprite);
  }

  addTableCards() {
    const card0 = this.game.table_cards[0];
    const card1 = this.game.table_cards[1];

    if (card1) this.addTableCard(card1);

    if (card0) {
      const sprite = this.addTableCard(card0);

      if (this.placeIsPlayable("table")) {
        makePlayable(sprite, this.onTableClick.bind(this));
      }
    }
  }

  addTableCard(cardName: string) {
    const texture = this.textures[cardName];
    const sprite = makeCardSprite(texture, TABLE_CARD_X, TABLE_CARD_Y);

    this.sprites.tables.unshift(sprite);
    this.stage.addChild(sprite);

    return sprite;
  }

  addHand(player: Player) {
    for (let i = 0; i < player.hand.length; i++) {
      const card = player.hand[i];
      const name = card["face_up?"] ? card.name : DOWN_CARD;

      const texture = this.textures[name];
      const coord = handCardCoord(player.position, i);
      const sprite = makeCardSprite(texture, coord.x, coord.y, coord.rotation);

      const isUsersCard = player.id === this.game.player_id;
      const place = `hand_${i}` as Place;

      if (isUsersCard && this.placeIsPlayable(place)) {
        makePlayable(sprite, () => this.onHandClick(player.id, i));
      }

      this.sprites.hands[player.position][i] = sprite;
      this.stage.addChild(sprite);
    }
  }

  addHeldCard(player: Player) {
    if (player.held_card == null) throw new Error("held_card is null");

    const texture = this.textures[player.held_card];
    const coord = heldCardCoord(player.position);
    const sprite = makeCardSprite(texture, coord.x, coord.y, coord.rotation);

    if (this.placeIsPlayable("held")) {
      makePlayable(sprite, this.onHeldClick.bind(this));
    }

    this.sprites.held = sprite;
    this.stage.addChild(sprite);
  }

  // events from server

  onGameStart(game: Game) {
    this.game = game;
    const numPlayers = game.players.length;

    for (let i = 0; i < numPlayers; i++) {
      const player = this.game.players[i];
      this.addHand(player);

      this.tweenHandDeal(player.position)
        .forEach((cardTween, cardIndex) => {
          cardTween.start();

          const isLastCard =
            i === numPlayers - 1
            && cardIndex === HAND_SIZE - 1;

          if (isLastCard) {
            cardTween.onComplete(() => {
              this.tweenDeckDeal()
                .onComplete(() => {
                  this.addTableCards();
                  this.tweenTableDeal().start();
                })
                .start();
            });
          }
        });
    }
  }

  onPlayerJoin(game: Game, _player_id: number) {
    this.game = game;
  }

  onGameEvent(game: Game, event: GameEvent) {
    this.game = game;

    switch (event.action) {
      case "flip":
        this.onFlip(event);
        break;

      case "take_from_deck":
        this.onTakeFromDeck(event);
        break;

      case "take_from_table":
        this.onTakeFromTable(event);
        break;

      case "swap":
        this.onSwap(event);
        break;

      case "discard":
        this.onDiscard(event);
        break;
    }
  }

  onFlip(event: GameEvent) {
    const player = this.findPlayer(event.player_id)!;
    const index = event.hand_index!;

    const handSprites = this.sprites.hands[player.position];
    const handSprite = handSprites[index];

    const cardName = player.hand[index]["name"];
    handSprite.texture = this.textures[cardName];

    this.tweenWiggle(handSprite).start();

    for (let i = 0; i < handSprites.length; i++) {
      const place = `hand_${i}` as Place;

      if (!this.placeIsPlayable(place)) {
        makeUnplayable(handSprites[i]);
      }
    }

    const deckSprite = this.sprites.deck;
    if (deckSprite && this.placeIsPlayable("deck")) {
      makePlayable(deckSprite, this.onDeckClick.bind(this));
    }

    const tableSprite = this.sprites.tables[0];
    if (tableSprite && this.placeIsPlayable("table")) {
      makePlayable(tableSprite, this.onTableClick.bind(this));
    }
  }

  onTakeFromDeck(event: GameEvent) {
    const player = this.findPlayer(event.player_id)!;

    this.addHeldCard(player);
    this.tweenHeldFromDeck(player.position).start();

    const isUsersEvent = player.id === this.game.player_id;

    if (isUsersEvent) {
      makeUnplayable(this.sprites.deck!);

      const tableSprite = this.sprites.tables[0];
      if (tableSprite) makeUnplayable(tableSprite);

      const handSprites = this.sprites.hands[player.position];

      handSprites.forEach((sprite, index) => {
        makePlayable(sprite, () => this.onHandClick(player.id, index));
      });
    }
  }

  onTakeFromTable(event: GameEvent) {
    const player = this.findPlayer(event.player_id)!;
    this.addHeldCard(player);

    const [tableSprite, heldTween] = this.tweenHeldFromTable(player.position);
    heldTween.start();

    const isUsersEvent = player.id === this.game.player_id;

    if (isUsersEvent) {
      makeUnplayable(tableSprite);

      const deckSprite = this.sprites.deck;
      if (deckSprite) makeUnplayable(deckSprite);

      const handSprites = this.sprites.hands[player.position];

      handSprites.forEach((sprite, index) => {
        makePlayable(sprite, () => this.onHandClick(player.id, index));
      });
    }
  }

  onSwap(event: GameEvent) {
    const player = this.findPlayer(event.player_id)!;
    const index = event.hand_index!;

    const handCard = player.hand[index].name;
    const handSprite = this.sprites.hands[player.position][index];

    handSprite.visible = false;
    handSprite.texture = this.textures[handCard];

    let tableSprite = this.sprites.tables[0];
    const tableCard = this.game.table_cards[0];

    if (tableCard) {
      const firstTexture = this.textures[tableCard];

      if (tableSprite) {
        tableSprite.texture = firstTexture;

        const secondCard = this.game.table_cards[1];
        let secondSprite = this.sprites.tables[1];

        if (secondCard) {
          const secondTexture = this.textures[secondCard];

          if (secondSprite) {
            secondSprite.texture = secondTexture;
          } else {
            secondSprite = makeCardSprite(secondTexture, TABLE_CARD_X, TABLE_CARD_Y);
            this.sprites.tables[1] = secondSprite;
            this.stage.addChild(secondSprite)

            // redraw the first table card so it's on top
            tableSprite.visible = false;
            makeUnplayable(tableSprite);

            tableSprite = makeCardSprite(firstTexture, TABLE_CARD_X, TABLE_CARD_Y);
            this.sprites.tables[0] = tableSprite;
            this.stage.addChild(tableSprite);
          }
        }
      } else {
        tableSprite = makeCardSprite(firstTexture, TABLE_CARD_X, TABLE_CARD_Y);
        this.sprites.tables[0] = tableSprite;
        this.stage.addChild(tableSprite);
      }
    }

    this.tweenSwapHeldTable(player.position, handSprite, tableSprite);

    const isUsersEvent = player.id === this.game.player_id;

    if (isUsersEvent) {
      for (const sprite of this.sprites.hands[player.position]) {
        makeUnplayable(sprite);
      }
    }

    if (this.placeIsPlayable("deck")) {
      makePlayable(this.sprites.deck!, this.onDeckClick.bind(this));
    }

    if (this.placeIsPlayable("table")) {
      makePlayable(tableSprite, this.onTableClick.bind(this));
    }
  }

  onDiscard(event: GameEvent) {
    const player = this.findPlayer(event.player_id)!;

    this.addTableCards();
    this.tweenTableDiscard(player.position).start();

    this.sprites.hands[player.position].forEach((sprite, index) => {
      const place = `hand_${index}` as Place;

      if (!this.placeIsPlayable(place)) {
        makeUnplayable(sprite);
      }
    });

    if (this.placeIsPlayable("deck")) {
      makePlayable(this.sprites.deck!, this.onDeckClick.bind(this));
    }
  }

  // events from client

  onHandClick(player_id: number, hand_index: number) {
    if (player_id === this.game.player_id) {
      this.pushEvent("hand_click", { player_id, hand_index });
    } else {
      throw new Error("wrong player_id");
    }
  }

  onDeckClick() {
    const player_id = this.game.player_id;
    this.pushEvent("deck_click", { player_id });
  }

  onTableClick() {
    const player_id = this.game.player_id;
    this.pushEvent("table_click", { player_id });
  }

  onHeldClick() {
    const player_id = this.game.player_id;
    this.pushEvent("held_click", { player_id });
  }

  // util

  placeIsPlayable(place: Place): boolean {
    return this.game.playable_cards.includes(place);
  }

  findPlayer(playerId: number) {
    return this.game.players.find(p => p.id === playerId);
  }

  // tweens

  tweenHandDeal(position: Position) {
    const handSprites = this.sprites.hands[position];
    const cardTweens: Tween<PIXI.Sprite>[] = [];

    for (let i = handSprites.length - 1; i >= 0; i--) {
      const cardSprite = handSprites[i];

      const toX = cardSprite.x;
      const toY = cardSprite.y;

      cardSprite.x = DECK_X_INIT;
      cardSprite.y = DECK_Y + DECK_Y_OFFSET;
      cardSprite.rotation = 0;

      const rotation = playerRotation(position);

      const tween = new Tween(cardSprite)
        .to({ x: toX, y: toY, rotation }, 800)
        .easing(Easing.Cubic.InOut)
        .delay((HAND_SIZE - 1 - i) * 180);

      cardTweens.push(tween);
    }

    return cardTweens;
  }

  tweenDeckDeal() {
    const deckSprite = this.sprites.deck;
    if (deckSprite == null) throw new Error("deck sprite is null");

    return new Tween(deckSprite)
      .to({ x: DECK_X }, 200)
      .easing(Easing.Quadratic.Out)
  }

  tweenTableDeal() {
    const deckSprite = this.sprites.deck;
    if (deckSprite == null) throw new Error("deck sprite is null");

    const tableSprite = this.sprites.tables[0];
    if (tableSprite == null) throw new Error("table sprite is null");

    const toX = tableSprite.x;
    const toY = tableSprite.y;

    tableSprite.x = deckSprite.x;
    tableSprite.y = deckSprite.y;

    return new Tween(tableSprite)
      .to({ x: toX, y: toY }, 400)
      .easing(Easing.Quadratic.Out)
  }

  tweenWiggle(sprite: PIXI.Sprite, duration = 150, distance = 1, repeats = 2) {
    const startX = sprite.x;

    // go back to the start after wiggling
    const tweenReturn = new Tween(sprite)
      .to({ x: startX }, duration / 2)
      .easing(Easing.Quadratic.Out);

    sprite.x = startX - distance;

    return new Tween(sprite)
      .to({ x: startX + distance }, duration / repeats)
      .easing(Easing.Quintic.InOut)
      .repeat(repeats)
      .yoyo(true)
      .chain(tweenReturn);
  }

  tweenHeldFromDeck(position: Position) {
    const heldSprite = this.sprites.held!;

    const toX = heldSprite.x;
    const toY = heldSprite.y;

    const deckSprite = this.sprites.deck!;

    heldSprite.x = deckSprite.x;
    heldSprite.y = deckSprite.y + DECK_Y_OFFSET;
    heldSprite.rotation = 0;

    const rotation = playerRotation(position);

    return new Tween(heldSprite)
      .to({ x: toX, y: toY, rotation }, 800)
      .delay(150)
      .easing(Easing.Quadratic.InOut);
  }

  tweenHeldFromTable(position: Position): [PIXI.Sprite, Tween<PIXI.Sprite>] {
    const heldSprite = this.sprites.held!;

    const toX = heldSprite.x;
    const toY = heldSprite.y;

    const tableSprite = this.sprites.tables.shift()!;

    heldSprite.x = tableSprite.x;
    heldSprite.y = tableSprite.y;
    heldSprite.rotation = 0;

    const rotation = playerRotation(position);

    const tween = new Tween(heldSprite)
      .onStart(() => tableSprite.visible = false)
      .to({ x: toX, y: toY, rotation }, 800)
      .easing(Easing.Quadratic.InOut);

    return [tableSprite, tween];
  }

  tweenTableDiscard(position: Position) {
    const tableSprite = this.sprites.tables[0]!;

    const heldSprite = this.sprites.held!;
    heldSprite.visible = false;

    const toX = tableSprite.x;
    const toY = tableSprite.y;

    tableSprite.x = heldSprite.x;
    tableSprite.y = heldSprite.y;
    tableSprite.rotation = playerRotation(position);

    return new Tween(tableSprite)
      .to({ x: toX, y: toY, rotation: 0 }, 800)
      .easing(Easing.Quadratic.InOut)
  }

  tweenSwapHeldTable(position: Position, handSprite: any, tableSprite: any) {
    const heldSprite = this.sprites.held!;

    const toX = handSprite.x;
    const toY = handSprite.y;

    tableSprite.x = toX;
    tableSprite.y = toY;
    tableSprite.rotation = playerRotation(position);

    new Tween(heldSprite)
      .to({ x: toX, y: toY }, 500)
      .easing(Easing.Quadratic.InOut)
      .onComplete(obj => {
        obj.visible = false;
        handSprite.visible = true;
      })
      .start();

    new Tween(tableSprite)
      .to({ x: TABLE_CARD_X, y: TABLE_CARD_Y, rotation: 0 }, 700)
      .easing(Easing.Quadratic.InOut)
      .delay(200)
      .start();
  }
}

// sprite helpers

function makeCardSprite(texture: PIXI.Texture, x = 0, y = 0, rotation = 0) {
  const sprite = PIXI.Sprite.from(texture);

  sprite.anchor.set(0.5);
  sprite.scale.set(CARD_SCALE, CARD_SCALE);

  sprite.x = x;
  sprite.y = y;
  sprite.rotation = rotation;

  return sprite;
}

const PLAYABLE_FILTER = new OutlineFilter(2, 0xff00ff, 1.0);

function makePlayable(sprite: PIXI.Sprite, callback: (sprite: PIXI.Sprite) => any) {
  sprite.eventMode = "static";
  sprite.cursor = "hover"
  sprite.filters = [PLAYABLE_FILTER];

  sprite.removeAllListeners();
  sprite.on("pointerdown", event => callback(event.currentTarget as PIXI.Sprite));
}

function makeUnplayable(sprite: PIXI.Sprite) {
  sprite.eventMode = "none";
  sprite.cursor = "default";
  sprite.filters = [];
  sprite.removeAllListeners();
}

// sprite coords

function deckX(gameStatus: string) {
  return gameStatus == "init" ? DECK_X_INIT : DECK_X;
}

function playerRotation(position: Position) {
  return position == "left" || position === "right"
    ? toRadians(90)
    : 0;
}

function heldCardCoord(
  position: Position, yPadding = HAND_Y_PADDING
) {
  let x: number;
  let y: number;

  switch (position) {
    case "bottom":
      x = CENTER_X + CARD_WIDTH * 2.5;
      y = GAME_HEIGHT - CARD_HEIGHT - yPadding;
      break;

    case "left":
      x = CARD_HEIGHT + yPadding;
      y = CENTER_Y + CARD_WIDTH * 2.5;
      break;

    case "top":
      x = CENTER_X - CARD_WIDTH * 2.5;
      y = CARD_HEIGHT + yPadding;
      break;

    case "right":
      x = GAME_WIDTH - CARD_HEIGHT - yPadding;
      y = CENTER_Y - CARD_WIDTH * 2.5
      break;
  }

  const rotation = playerRotation(position);
  return { x, y, rotation }
}

function handCardCoord(
  position: Position, index: number, xPadding = HAND_X_PADDING, yPadding = HAND_Y_PADDING
) {
  let x = 0, y = 0;

  if (position === "bottom") {
    switch (index) {
      case 0:
        x = CENTER_X - CARD_WIDTH - xPadding;
        y = GAME_HEIGHT - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        break;

      case 1:
        x = CENTER_X;
        y = GAME_HEIGHT - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        break;

      case 2:
        x = CENTER_X + CARD_WIDTH + xPadding;
        y = GAME_HEIGHT - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        break;

      case 3:
        x = CENTER_X - CARD_WIDTH - xPadding;
        y = GAME_HEIGHT - CARD_HEIGHT / 2 - yPadding;
        break;

      case 4:
        x = CENTER_X;
        y = GAME_HEIGHT - CARD_HEIGHT / 2 - yPadding;
        break;

      case 5:
        x = CENTER_X + CARD_WIDTH + xPadding;
        y = GAME_HEIGHT - CARD_HEIGHT / 2 - yPadding;
        break;
    }
  } else if (position === "top") {
    switch (index) {
      case 0:
        x = CENTER_X + CARD_WIDTH + xPadding;
        y = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        break;

      case 1:
        x = CENTER_X;
        y = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        break;

      case 2:
        x = CENTER_X - CARD_WIDTH - xPadding;
        y = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        break;

      case 3:
        x = CENTER_X + CARD_WIDTH + xPadding;
        y = CARD_HEIGHT / 2 + yPadding;
        break;

      case 4:
        x = CENTER_X;
        y = CARD_HEIGHT / 2 + yPadding;
        break;

      case 5:
        x = CENTER_X - CARD_WIDTH - xPadding;
        y = CARD_HEIGHT / 2 + yPadding;
        break;
    }
  } else if (position === "left") {
    switch (index) {
      case 0:
        x = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        y = CENTER_Y - CARD_WIDTH - xPadding;
        break;

      case 1:
        x = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        y = CENTER_Y;
        break;

      case 2:
        x = CARD_HEIGHT * 1.5 + yPadding * 1.3;
        y = CENTER_Y + CARD_WIDTH + xPadding;
        break;

      case 3:
        x = CARD_HEIGHT / 2 + yPadding;
        y = CENTER_Y - CARD_WIDTH - xPadding;
        break;

      case 4:
        x = CARD_HEIGHT / 2 + yPadding;
        y = CENTER_Y;
        break;

      case 5:
        x = CARD_HEIGHT / 2 + yPadding;
        y = CENTER_Y + CARD_WIDTH + xPadding;
        break;
    }
  } else if (position === "right") {
    switch (index) {
      case 0:
        x = GAME_WIDTH - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        y = CENTER_Y + CARD_WIDTH + xPadding;
        break;

      case 1:
        x = GAME_WIDTH - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        y = CENTER_Y;
        break;

      case 2:
        x = GAME_WIDTH - CARD_HEIGHT * 1.5 - yPadding * 1.3;
        y = CENTER_Y - CARD_WIDTH - xPadding;
        break;

      case 3:
        x = GAME_WIDTH - CARD_HEIGHT / 2 - yPadding;
        y = CENTER_Y + CARD_WIDTH + xPadding;
        break;

      case 4:
        x = GAME_WIDTH - CARD_HEIGHT / 2 - yPadding;
        y = CENTER_Y;
        break;

      case 5:
        x = GAME_WIDTH - CARD_HEIGHT / 2 - yPadding;
        y = CENTER_Y - CARD_WIDTH - xPadding;
        break;
    }
  }

  const rotation = playerRotation(position);
  return { x, y, rotation };
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}
