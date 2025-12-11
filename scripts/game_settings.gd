# ゲーム設定管理ファイル
# UI切替やデバッグ設定など
extends Node

class_name GameSettings

# === UI設定 ===
# クリーチャー情報パネルを使用するか
# true: 新しいクリーチャー情報パネル（左カード、中央Yes/No、右詳細）
# false: 既存のcard_selection_ui（開発中はこちら推奨）
static var use_creature_info_panel: bool = true

# === デバッグ設定 ===
static var debug_mode: bool = false
