extends VBoxContainer

# RESPONSIBILITY: Own field-repair controls, quantity selection and preview text.
# DOES NOT: Spend Salvage or change Hull; the expedition validates repair_requested.
signal repair_requested(amount: int, revision: int)
signal description_changed(text: String)

const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Repairs = preload("res://scripts/repair_rules.gd")

var preview: VBoxContainer
var selector: HSlider
var confirm: Button
var _minus: Button
var _plus: Button
var _confirmation_revision: int = -1
# Read the supplied model for current limits; all mutations remain in ExpeditionState.
var _state: Resource
var _heading: String


func _init() -> void:
	preview = preload("res://scripts/ui/repair_preview.gd").new()
	add_child(preview)
	var row = HBoxContainer.new()
	add_child(row)
	_minus = Button.new()
	_minus.text = "−"
	_minus.custom_minimum_size = Vector2(56, 48)
	Presentation.action(_minus)
	row.add_child(_minus)
	selector = HSlider.new()
	selector.step = 1
	selector.custom_minimum_size = Vector2(180, 48)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(selector)
	_plus = Button.new()
	_plus.text = "+"
	_plus.custom_minimum_size = Vector2(56, 48)
	Presentation.action(_plus)
	row.add_child(_plus)
	confirm = Button.new()
	confirm.custom_minimum_size.y = 48
	confirm.disabled = true
	Presentation.action(confirm)
	add_child(confirm)
	_minus.pressed.connect(func(): selector.value -= 1)
	_plus.pressed.connect(func(): selector.value += 1)
	selector.value_changed.connect(_update_preview)
	confirm.pressed.connect(_request_repair)


func present(state: Resource, heading: String) -> void:
	_state = state
	_heading = heading
	_confirmation_revision = state.service_revision
	selector.max_value = state.field_repair_limit()
	selector.set_value_no_signal(state.field_repair_limit())
	_update_preview(0)


# Navigation closes the view and releases the previous expedition's model reference.
func clear() -> void:
	_state = null
	_confirmation_revision = -1
	selector.set_value_no_signal(0)
	confirm.disabled = true


# Called only after the expedition accepts the request; clear the consumed selection.
func refresh_after_repair() -> void:
	_confirmation_revision = _state.service_revision
	selector.set_value_no_signal(0)
	_update_preview(0)


func _update_preview(_value: float) -> void:
	if _state == null:
		return
	var limit: int = _state.field_repair_limit()
	selector.max_value = limit
	var amount: int = mini(int(selector.value), limit)
	var cost: int = Repairs.quantity_cost(amount, Repairs.FIELD_SALVAGE_PER_HULL)
	var text: String = (
		_heading
		+ (
			"\nField repair: 2 Salvage / Hull · Maximum affordable: %d\nPermanent Hull carries between battles. Excess is temporary plating."
			% limit
		)
	)
	preview.show_repair(
		_state.hull,
		_state.ship().hull_capacity,
		_state.salvage,
		amount,
		Repairs.FIELD_SALVAGE_PER_HULL
	)
	if _state.hull >= _state.ship().hull_capacity:
		text += "\nHull full · Field repairs cannot create Ablative Plating."
	elif limit == 0:
		text += "\nRequires at least 2 Salvage to repair 1 Hull."
	description_changed.emit(text)
	selector.editable = limit > 0
	_minus.disabled = amount <= 0
	_plus.disabled = amount >= limit
	confirm.text = "Confirm +%d Hull · %d Salvage" % [amount, cost]
	confirm.disabled = (
		amount <= 0
		or not _state.field_repairs_open
		or _confirmation_revision != _state.service_revision
	)


func _request_repair() -> void:
	if _state == null or confirm.disabled:
		return
	repair_requested.emit(int(selector.value), _confirmation_revision)
