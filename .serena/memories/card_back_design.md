# カード裏面デザイン実装メモ

## 作成ファイル
- `assets/shaders/card_back.gdshader` - 裏面デザイン用GDShader（spatial）
- `scenes/test_card_back.tscn` - プレビュー用テストシーン
- `scripts/test_card_back.gd` - テストシーン用スクリプト

## デザイン内容
- ダーク青緑の星空背景
- 金色の三日月（SDF描画）
- 金色の2重枠線
- 「A R C A N A」テキスト（SubViewport + Label）
- テキスト下に金色のアンダーライン

## シェーダーパラメータ（インスペクターで調整可能）
- Moon Size: 0.1
- Moon Offset: 0.04
- Moon Inner Size: 0.698
- Moon Angle: 45.0
- Moon Position: (0.48, 0.3)

## 次のタスク
- カード配布時に裏面→表面のフリップアニメーション実装
- hand_display.gdのcreate_card_nodeでフリップを呼び出す
- card.gdにplay_flip_animation()を追加する（scale.xを1→0→1、中間点で裏面シェーダーを切り替え）
