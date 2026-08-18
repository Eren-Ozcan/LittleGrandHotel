extends Node
## Verification harness for "Disconnect account": the row only exists while an
## account is linked, it asks twice, and disconnecting resets the cloud identity
## without touching the local save.
##
## The linked state is faked by handing FirebaseAuth a session, because a real
## browser sign-in cannot run in a test.
##
## Run: tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/unlink_check.tscn
## Add "shot" to the user args to also write user://unlink.png.

var _main: Node


func _find(node: Node, text: String) -> Button:
	if node is Button and node.has_meta("title_label"):
		var title_l: Label = node.get_meta("title_label")
		if title_l != null and title_l.text.begins_with(text):
			return node
	for child in node.get_children():
		var found := _find(child, text)
		if found != null:
			return found
	return null


func _ready() -> void:
	var game := get_node("/root/Game")
	var cloud := get_node("/root/CloudSave")
	game.tutorial_seen = true
	game.offline_earned = 0
	game.auto_renew_count = 0
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_main._finish_loading_screen()
	await get_tree().process_frame

	# Pretend the player finished a Google sign-in on this device.
	var auth: Node = cloud._auth
	auth._state_loaded = true
	auth._uid = "test-uid-1234"
	auth._provider = "google.com"
	auth._refresh_token = "test-refresh"
	cloud._last_synced_uid = auth._uid
	cloud._rev = 7
	print("U1 is_linked=", cloud.is_linked(), " (expected true)")

	_main._profile_tab = "account"
	_main._open_popup("Profile", _main._build_profile_popup)
	await get_tree().process_frame
	var unlink_b := _find(get_tree().root, "Disconnect account")
	print("U2 row_present=", unlink_b != null)
	if unlink_b == null:
		get_tree().quit()
		return
	if "shot" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://unlink.png")
		print("SHOT_SAVED: ", ProjectSettings.globalize_path("user://unlink.png"))

	var coins_before: int = game.coins
	unlink_b.emit_signal("pressed")
	await get_tree().process_frame
	print("U3 first tap still_linked=", cloud.is_linked(),
		" confirm_shown=", _find(get_tree().root, "Tap again to disconnect") != null)

	var confirm := _find(get_tree().root, "Tap again to disconnect")
	confirm.emit_signal("pressed")
	await get_tree().process_frame
	print("U4 after second tap is_linked=", cloud.is_linked(),
		" uid=", "'%s'" % auth.uid(), " rev=", cloud._rev,
		" coins_kept=", game.coins == coins_before)

	# The row must be gone and the sign-in offer back in its place.
	print("U5 row_gone=", _find(get_tree().root, "Disconnect account") == null,
		" link_offer_back=", _find(get_tree().root, "Link with Google") != null)
	get_tree().quit()
