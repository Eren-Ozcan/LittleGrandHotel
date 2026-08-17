extends Node
## Temporary verification harness for the pending UI checklist:
## dirty-room clean button, two-tap gem skip with an interfering
## state_changed, and the "Running" primary label while a shift earns nothing.

var _main: Node


func _find(node: Node, text: String) -> Button:
	# Rows keep their title Label in the button's "title_label" meta.
	if node is Button and node.has_meta("title_label"):
		var title_l: Label = node.get_meta("title_label")
		if title_l != null and title_l.text.begins_with(text):
			return node
	for child in node.get_children():
		var found := _find(child, text)
		if found != null:
			return found
	return null


func _root() -> Node:
	return get_tree().root


func _ready() -> void:
	var game := get_node("/root/Game")
	game.tutorial_seen = true
	game.offline_earned = 0
	game.auto_renew_count = 0
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_main._finish_loading_screen()
	game.coins += 100000
	game.gems += 500
	await get_tree().process_frame

	# --- 5. primary button says "Running" while a shift earns nothing ---
	game.start_shift(8)
	game.pending_income = 0.0
	_main._update_live_labels()
	print("A5 primary=", _main.primary_label.text, " sub=", _main.shift_bar_label.text,
		" disabled=", _main.collect_button.disabled)

	# --- 7. dirty room opens with a "Clean this room" button ---
	game.rooms[0].dirty = true
	_main.selected_room = 0
	_main._open_popup("Room", _main._build_room_popup)
	await get_tree().process_frame
	var clean_b := _find(_root(), "Clean this room")
	print("A7 clean_button=", clean_b != null)
	if clean_b != null:
		clean_b.emit_signal("pressed")
		await get_tree().process_frame
		print("A7 after press dirty=", game.rooms[0].dirty)
	_main._close_popup()
	await get_tree().process_frame

	# --- 6. two-tap gem finish survives an interfering state_changed ---
	print("A6 housekeeping_active=", game.housekeeping_active())
	_main._open_popup("Shift", _main._build_shift_popup)
	await get_tree().process_frame
	var skip_b := _find(_root(), "Finish now")
	print("A6 first tap found=", skip_b != null)
	if skip_b == null:
		get_tree().quit()
		return
	skip_b.emit_signal("pressed")
	await get_tree().process_frame
	print("A6 armed=", _main._skip_shift_armed,
		" label=", (_find(_root(), "Tap again to finish anyway") != null))
	# The old bug: any state change rebuilt the popup and wiped the confirm.
	game.rooms[1].dirty = true
	game.emit_signal("state_changed")
	await get_tree().process_frame
	var again := _find(_root(), "Tap again to finish anyway")
	print("A6 after state_changed confirm_still_there=", again != null,
		" armed=", _main._skip_shift_armed)
	if again != null:
		again.emit_signal("pressed")
		await get_tree().process_frame
		print("A6 after second tap shift_active=", game.shift_active(),
			" remaining=", game.shift_remaining_game_hours())
	get_tree().quit()
