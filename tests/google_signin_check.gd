extends Node
## Verification harness for the Google sign-in failure paths.
##
## The browser round itself cannot run headless, so this drives the parts that
## can: the backoff/terminal-error decision in the token exchange and the
## player-facing message each failure reason turns into.
##
## Run: tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/google_signin_check.tscn

const GoogleSignInScript := preload("res://src/cloud/google_signin.gd")

var _passed := 0
var _failed := 0


func _check(label: String, got: Variant, expected: Variant) -> void:
	if got == expected:
		_passed += 1
		print("  OK   ", label)
	else:
		_failed += 1
		print("  FAIL ", label, " got=", got, " expected=", expected)


func _ready() -> void:
	var cloud := get_node("/root/CloudSave")
	var signin: Node = cloud._google_signin

	# The default provider must still be the one CloudSave asks for a token,
	# otherwise the failure messages below would never be reached.
	_check("default provider is GoogleSignIn",
		cloud._google_id_token_provider.get_object() == signin, true)

	# Each reason maps to its own message; unknown reasons keep the old text.
	var cases := {
		"access_denied": "Google sign-in was declined.",
		"browser_timeout": "Sign-in took too long in the browser — try again from here.",
		"no_foreground": "Sign-in needs the game open — try again and come straight back.",
		"network": "Google could not be reached — check your connection and try again.",
		"invalid_grant": "That sign-in expired before it finished — please try again.",
		"invalid_client": "This build's Google sign-in is misconfigured; please contact support.",
		"": "Google sign-in was not completed.",
		"something_new": "Google sign-in was not completed.",
	}
	for reason in cases:
		signin._last_error = reason
		_check("message for '%s'" % reason, cloud._signin_failure_message(), cases[reason])

	# A code that Google already rejected must not be retried; a network blip must.
	_check("invalid_grant is terminal",
		"invalid_grant" in GoogleSignInScript._TERMINAL_TOKEN_ERRORS, true)
	_check("network is retried",
		"network" in GoogleSignInScript._TERMINAL_TOKEN_ERRORS, false)

	# The retry budget has to outlast a phone whose data is still waking up.
	var budget := 0.0
	for wait in GoogleSignInScript.EXCHANGE_BACKOFF_SEC:
		budget += float(wait)
	print("  INFO retry budget=", budget, "s over ",
		GoogleSignInScript.EXCHANGE_BACKOFF_SEC.size(), " attempts")
	_check("retry budget is at least 30s", budget >= 30.0, true)
	_check("foreground wait matches the browser round",
		GoogleSignInScript.FOREGROUND_WAIT_SEC == GoogleSignInScript.FLOW_TIMEOUT_SEC, true)

	print("SONUC: ", _passed, " gecti, ", _failed, " kaldi")
	get_tree().quit()
