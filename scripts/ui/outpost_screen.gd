extends VBoxContainer
# RESPONSIBILITY: Own service tiles, selection and the outpost purchase confirmation.
# DOES NOT: Spend Salvage, change Hull or resolve rewards; emit intent to Expedition.
signal purchase_requested(slot: int, amount: int, revision: int)
signal selection_changed(slot: int)
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Text = preload("res://scripts/ui/expedition_text.gd")
const Tile = preload("res://scripts/ui/encounter_tile.gd")
const Repairs = preload("res://scripts/repair_rules.gd")
var options: GridContainer
var buttons: Array[Button] = []
var confirmation: CanvasLayer
var footer: HBoxContainer
var note: Label
var preview: VBoxContainer
var selector: HSlider
var confirm_button: Button
var selected_slot: int = -1
var revision: int = -1
# Read-only access to authoritative price/availability queries; never mutate this model.
var _state: Resource
var _allows_activation: Callable


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options = GridContainer.new()
	options.columns = 2
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("h_separation", 10)
	options.add_theme_constant_override("v_separation", 10)
	add_child(options)
	confirmation = preload("res://scripts/ui/approach_confirmation.gd").new()
	add_child(confirmation)
	confirmation.cancelled.connect(cancel_selection)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	confirmation.column.add_child(footer)
	confirmation.column.move_child(footer, 1)
	preview = preload("res://scripts/ui/repair_preview.gd").new()
	confirmation.column.add_child(preview)
	confirmation.column.move_child(preview, 1)
	preview.hide()
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 20)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(note)
	selector = HSlider.new()
	selector.custom_minimum_size = Vector2(180, 60)
	selector.step = 1
	selector.value_changed.connect(update_quantity)
	footer.add_child(selector)
	selector.hide()
	confirm_button = confirmation.initiate
	confirm_button.text = "Confirm"
	confirm_button.disabled = true
	confirm_button.pressed.connect(confirm_purchase)
	footer.hide()


func configure(state: Resource, allows_activation: Callable) -> void:
	_state = state
	_allows_activation = allows_activation
	revision = state.service_revision
	note.text = "Service station · No travel FTL · Free to leave"
	for slot in range(state.service.poi.approaches.size()):
		var approach: Resource = state.service.poi.approaches[slot]
		var details: String
		if approach.success.hull > 0:
			details = (
				"%d Salvage / %s · Select quantity\nHull %d/%d · Plating %d/%d"
				% [
					state.station_hull_unit_cost(),
					"plating" if state.station_plating_mode() else "Hull",
					state.hull,
					state.ship().hull_capacity,
					maxi(0, state.hull - state.ship().hull_capacity),
					Repairs.STATION_PLATING_LIMIT
				]
			)
		else:
			details = (
				"%d Salvage · %s"
				% [state.service_cost(slot), Text.compact_outcome(state, approach.success)]
			)
		var reason: String = state.service_locked_reason(slot)
		if not reason.is_empty():
			details += "\nLOCKED — " + reason
		var button = Tile.new()
		button.configure(
			state.station_hull_title() if state.service_is_repair(slot) else approach.title,
			details,
			Presentation.COLORS.special
		)
		button.disabled = not reason.is_empty()
		button.refresh_style()
		button.set_rich_details(Text.highlight_outcome(details))
		button.pressed.connect(
			func():
				if is_inside_tree() and not button.disabled and _allows_activation.call():
					select_service(slot)
		)
		options.add_child(button)
		buttons.append(button)


func select_service(slot: int) -> void:
	if _state == null or not _state.can_visit(_state.SERVICE_INDEX):
		return
	if not _state.service_locked_reason(slot).is_empty():
		return
	selected_slot = slot
	selection_changed.emit(slot)
	footer.show()
	var repairing: bool = _state.service_is_repair(slot)
	preview.visible = repairing
	note.visible = not repairing
	selector.visible = repairing
	for index in range(buttons.size()):
		buttons[index].selected = index == slot
		buttons[index].refresh_style()
	confirm_button.disabled = revision != _state.service_revision
	if repairing:
		selector.max_value = _state.station_repair_limit()
		selector.set_value_no_signal(0)
		update_quantity(0)
	else:
		note.text = (
			"Cost %d Salvage · Balance after purchase: %d"
			% [_state.service_cost(slot), _state.salvage - _state.service_cost(slot)]
		)
	confirmation.present(
		_state.station_hull_title() if repairing else _state.service.poi.approaches[slot].title
	)


func update_quantity(_value: float) -> void:
	if _state == null or not _state.service_is_repair(selected_slot):
		return
	var amount: int = int(selector.value)
	note.text = (
		"+%d %s → Hull %d/%d · Cost %d Salvage"
		% [
			amount,
			"plating" if _state.station_plating_mode() else "Hull",
			_state.hull + amount,
			_state.ship().hull_capacity,
			_state.service_cost(selected_slot, amount)
		]
	)
	preview.show_repair(
		_state.hull,
		_state.ship().hull_capacity,
		_state.salvage,
		amount,
		_state.station_hull_unit_cost(),
		_state.station_plating_mode()
	)
	confirm_button.disabled = (
		amount <= 0 or amount > _state.station_repair_limit() or revision != _state.service_revision
	)


func cancel_selection() -> void:
	confirmation.dismiss()
	selected_slot = -1
	selection_changed.emit(-1)
	confirm_button.disabled = true
	selector.hide()
	selector.set_value_no_signal(0)
	for button in buttons:
		button.selected = false
		button.refresh_style()


func confirm_purchase() -> void:
	if (
		_state == null
		or not is_inside_tree()
		or not confirmation.shade.visible
		or confirm_button.disabled
	):
		return
	confirm_button.disabled = true
	confirmation.dismiss()
	purchase_requested.emit(selected_slot, int(selector.value), revision)


func show_purchase_complete() -> void:
	note.text = "Purchase complete · No travel FTL · Free to leave"


func clear() -> void:
	# Called before detaching: queued old controls must no longer emit valid actions.
	_state = null
	revision = -1
	cancel_selection()
