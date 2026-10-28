extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Gate = preload("res://scripts/expedition/approach_requirement.gd")
const Text = preload("res://scripts/ui/expedition_text.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	# Retained exploration-mode regression.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run():
	var state = State.new()
	state.start(0,preload("res://encounters/expedition_rules.tres"))
	var approach = load("res://encounters/mining_operation.tres").approaches[2].duplicate(true)
	var available: int = state.production(approach.requirement)
	approach.minimum_production = available+1
	approach.salvage_cost = 5
	state.salvage = 0
	var rng: int = state.rng.state
	var gate = state.approach_requirement(approach)
	check(gate.kind == Gate.Kind.PRODUCTION and gate.is_locked(),"Production gate wins over price gate")
	check(gate.current == available and gate.required == available+1,"Facts preserve actual production values")
	check(state.locked_reason(approach) == "Requires %s ≥%d (you have %d)" % [state.LABELS[approach.requirement],available+1,available],"Existing gate wording remains compatible")
	check(Text.requirement_text(gate,state.LABELS).contains("required (%d)"%available),"Compact wording uses supplied requirement facts")
	approach.minimum_production = available
	gate = state.approach_requirement(approach)
	check(gate.kind == Gate.Kind.SALVAGE and gate.required == 5 and gate.current == 0,"Exact production threshold passes; price remains authoritative")
	check(state.locked_reason(approach) == "Requires 5 Salvage (you have 0)","Legacy price wording preserved")
	state.salvage = 5
	approach.success.hull = 1
	state.hull = state.ship().hull_capacity
	gate = state.approach_requirement(approach)
	check(gate.kind == Gate.Kind.FULL_HULL,"Full repair target is locked after other gates pass")
	check(Text.requirement_text(gate,state.LABELS) == "Hull already full","Full Hull requirement stays visible")
	state.hull -= 1
	check(not state.approach_requirement(approach).is_locked() and state.locked_reason(approach).is_empty(),"Available option has no failed requirement")
	check(gate.kind == Gate.Kind.FULL_HULL,"Previously returned gate is a detached snapshot")
	check(state.rng.state == rng,"Queries do not sample gameplay RNG")
	# Very long content falls back to readable wrapping without exposing outcomes.
	var tile = preload("res://scripts/ui/encounter_tile.gd").new()
	tile.configure("An exceptionally long authored encounter choice", "75% +99 reward", Color.WHITE)
	tile.set_compact(true)
	tile.disabled = true
	tile.collapse_requirement("Synthesizer 12 required (2)")
	root.add_child(tile)
	tile.size.x = 320
	for i in range(24): await process_frame
	check(tile.heading.get_theme_font_size("font_size") >= 14,"Requirement has an explicit readability floor")
	check(tile.heading.autowrap_mode != TextServer.AUTOWRAP_OFF,"Long requirement wraps rather than shrinking indefinitely")
	check(tile.heading.text.contains("12 required (2)") and not tile.details.visible,"Actual gate retained; rewards stay hidden")
	check(tile.size.y > 42,"Fallback reserves space for all wrapped requirement text")
	tile.free()
	print("Approach requirements: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
