extends Node
## Repro: "gem ile vardiyayi bitirdikten sonra sure devam ediyor".
## Vardiya baslatir, skip_shift() cagirir ve sonraki karelerde vardiya
## durumunu / gokyuzu cipinin metnini yazdirir.

var _main: Node
var _t := 0.0


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
	if "autorenew" in OS.get_cmdline_user_args():
		print("buy_auto_renew -> ", game.buy_auto_renew(24))
	print("start_shift(8) -> ", game.start_shift(8))
	print("active=", game.shift_active(), " remaining=", game.shift_remaining_game_hours(),
		" auto_renew_left=", game.auto_renew_hours_left, " last_shift_hours=", game.last_shift_hours)
	await get_tree().create_timer(0.5).timeout
	print("gem cost=", game.skip_shift_gem_cost())
	print("skip_shift() -> ", game.skip_shift())
	print("after skip: active=", game.shift_active(),
		" remaining=", game.shift_remaining_game_hours(),
		" end_in=", game.shift_end_unix - game.now())
	for i in 3:
		await get_tree().create_timer(0.5).timeout
		print("t+%.1f active=%s remaining=%.4f chip=%s primary=%s / %s" % [
			(i + 1) * 0.5, game.shift_active(), game.shift_remaining_game_hours(),
			_main.shift_label.text, _main.primary_label.text, _main.shift_bar_label.text])
	get_tree().quit()

