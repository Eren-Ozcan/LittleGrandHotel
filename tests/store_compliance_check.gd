extends Node
## Verification harness for the store-compliance round:
## gem packs are granted exactly once (and survive an interrupted purchase),
## entitlements come back from a store restore, and restore_purchases()
## reports honestly when the store cannot be reached.
##
## Run: tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/store_compliance_check.tscn

## The purchase and deletion paths write to the real save (entitlements persist,
## and the deletion test resets the game), so the developer's save is stashed
## first and put back at the end — same discipline as tests/cloud_save_check.gd.
const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.storetest.bak"

var _main: Node


func _stash_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(BACKUP_PATH))


func _restore_save() -> void:
	if not FileAccess.file_exists(BACKUP_PATH):
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	print("  (test oncesi kayit geri yuklendi)")


func _ready() -> void:
	_stash_save()
	var game := get_node("/root/Game")
	var iap := get_node("/root/IAP")
	game.tutorial_seen = true
	game.offline_earned = 0
	game.auto_renew_count = 0
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_main._finish_loading_screen()
	await get_tree().process_frame

	# --- gem pack is granted exactly once through the mock purchase ---
	var before: int = game.gems
	iap.purchase("gems_medium")
	await get_tree().process_frame
	print("B1 gems delta=", game.gems - before, " (expected 350)")

	# --- an interrupted purchase that only comes back as a store restore ---
	before = game.gems
	iap.purchase_result.emit("gems_small", true)
	await get_tree().process_frame
	print("B2 restored gems delta=", game.gems - before, " (expected 100)")

	# --- entitlements restored from the store ---
	game.remove_ads = false
	game.permanent_income_mult = 1.0
	iap.purchase_result.emit("remove_ads", true)
	iap.purchase_result.emit("income_2x", true)
	await get_tree().process_frame
	print("B3 remove_ads=", game.remove_ads, " mult=", game.permanent_income_mult)

	# --- no store on desktop: restore must report failure, not a fake promise ---
	print("B4 restore_purchases()=", iap.restore_purchases(), " (expected false)")

	# --- deletion path: no-op success when the cloud is not configured,
	#     honest failure when it is configured but unreachable (desktop/offline) ---
	var cloud := get_node("/root/CloudSave")
	var deleted: bool = await cloud.delete_cloud_data()
	print("B5 cloud_enabled=", cloud.is_enabled(), " delete_cloud_data()=", deleted,
		" (expected true when not enabled, false when enabled but offline)")
	_main.queue_free()
	await get_tree().process_frame
	_restore_save()
	get_tree().quit()
