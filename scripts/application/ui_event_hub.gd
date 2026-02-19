extends Node
class_name UIEventHub
## UIイベントハブ — UIからのユーザーアクションを集約する横断層
## GSMが作成・所有し、各UIコンポーネントに注入される
## UIはイベントを発行するだけ。ロジックを一切知らない。

## 手札カードがタップされた
signal hand_card_tapped(card_index: int)

## ドミニオコマンドのキャンセルが要求された
signal dominio_cancel_requested()

## 降参が要求された
signal surrender_requested()
