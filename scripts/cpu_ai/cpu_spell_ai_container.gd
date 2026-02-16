## CPUSpellAIContainer - CPU AI統合参照コンテナ
##
## Phase 5-2: CPU AI参照を統合し、SpellPhaseHandler からのアクセスを単一参照化
## 責務: cpu_spell_ai, cpu_mystic_arts_ai, cpu_hand_utils, cpu_movement_evaluator の参照管理
##
## 初期化パターン: GameSystemManager._initialize_cpu_spell_ai_container() で作成
## パターン: SpellSystemContainer を踏襲（RefCounted で実装）

extends RefCounted
class_name CPUSpellAIContainer

# === 統合参照 ===
var cpu_spell_ai: CPUSpellAI = null
var cpu_mystic_arts_ai: CPUMysticArtsAI = null
var cpu_hand_utils: CPUHandUtils = null
var cpu_movement_evaluator: CPUMovementEvaluator = null


# === 初期化 ===

func setup(
	spell_ai: CPUSpellAI,
	mystic_arts_ai: CPUMysticArtsAI,
	hand_utils: CPUHandUtils,
	movement_evaluator: CPUMovementEvaluator
) -> void:
	"""CPU AI統合参照を初期化

	Args:
		spell_ai: CPUSpellAI インスタンス
		mystic_arts_ai: CPUMysticArtsAI インスタンス
		hand_utils: CPUHandUtils インスタンス
		movement_evaluator: CPUMovementEvaluator インスタンス
	"""
	cpu_spell_ai = spell_ai
	cpu_mystic_arts_ai = mystic_arts_ai
	cpu_hand_utils = hand_utils
	cpu_movement_evaluator = movement_evaluator

	# 初期化検証
	if not cpu_spell_ai:
		push_error("[CPUSpellAIContainer] cpu_spell_ai が null です")
	if not cpu_mystic_arts_ai:
		push_error("[CPUSpellAIContainer] cpu_mystic_arts_ai が null です")
	if not cpu_hand_utils:
		push_error("[CPUSpellAIContainer] cpu_hand_utils が null です")
	if not cpu_movement_evaluator:
		push_error("[CPUSpellAIContainer] cpu_movement_evaluator が null です")


# === 検証メソッド ===

func is_valid() -> bool:
	"""初期化状態を確認

	Returns:
		すべての参照が正常に初期化されている場合は true
	"""
	return (
		cpu_spell_ai != null and
		cpu_mystic_arts_ai != null and
		cpu_hand_utils != null and
		cpu_movement_evaluator != null
	)


# === デバッグメソッド ===

func debug_print_status() -> void:
	"""デバッグ情報を出力"""
	var status = "[CPUSpellAIContainer] Status:\n"
	status += "  - cpu_spell_ai: %s\n" % ("OK" if cpu_spell_ai else "NULL")
	status += "  - cpu_mystic_arts_ai: %s\n" % ("OK" if cpu_mystic_arts_ai else "NULL")
	status += "  - cpu_hand_utils: %s\n" % ("OK" if cpu_hand_utils else "NULL")
	status += "  - cpu_movement_evaluator: %s\n" % ("OK" if cpu_movement_evaluator else "NULL")
	status += "  - is_valid(): %s" % ("✓ 初期化完了" if is_valid() else "✗ 未初期化")

	print(status)
