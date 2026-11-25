extends "res://tests/test_case.gd"


func test_codes_round_trip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 200:
		var mode: String = ChallengeCode.MODES[rng.randi_range(0, ChallengeCode.MODES.size() - 1)]
		var seed := rng.randi()
		var diff := rng.randi_range(0, 2)
		var score := rng.randi_range(0, 2_000_000)
		var code := ChallengeCode.encode(mode, seed, diff, score)
		var d := ChallengeCode.decode(code)
		assert_eq(d, {"mode": mode, "seed": seed, "difficulty": diff, "score": score}, "round trip %s" % code)


func test_code_format() -> void:
	var code := ChallengeCode.encode("blitz", 123456789, 2, 14250)
	assert_true(code.begins_with("ORB-"), "prefix")
	assert_eq(code.length(), 4 + 4 + 1 + 4 + 1 + 6, "ORB-XXXX-XXXX-XXXXXX")
	assert_eq(ChallengeCode.encode("puzzle", 1, 1, 1), "", "puzzles can't be challenged")


func test_decode_is_forgiving() -> void:
	var code := ChallengeCode.encode("classic", 42, 1, 900)
	var want := ChallengeCode.decode(code)
	assert_eq(ChallengeCode.decode(code.to_lower()), want, "lowercase")
	assert_eq(ChallengeCode.decode(code.replace("-", " ")), want, "spaces instead of dashes")
	assert_eq(ChallengeCode.decode("ORBIT · Classic\n🟣🔵⚫\nScore 900\nBeat me: " + code), want, "whole pasted message")
	assert_eq(ChallengeCode.decode(code.replace("0", "O")), want, "letter O for zero")


func test_typos_are_rejected() -> void:
	var code := ChallengeCode.encode("zen", 777, 1, 4321)
	var body := code.replace("ORB-", "").replace("-", "")
	var rejected := 0
	for i in body.length():
		var idx := ChallengeCode.ALPHABET.find(body[i])
		var changed := body.substr(0, i) + ChallengeCode.ALPHABET[(idx + 1) % 32] + body.substr(i + 1)
		if ChallengeCode.decode("ORB" + changed).is_empty():
			rejected += 1
	assert_true(rejected >= body.length() - 1, "a mistyped character is caught (%d/%d)" % [rejected, body.length()])
	assert_true(ChallengeCode.decode("hello").is_empty(), "nonsense rejected")
	assert_true(ChallengeCode.decode("").is_empty(), "empty rejected")


func test_share_text() -> void:
	var t := ShareText.build("Daily Orbit", "Nov 25", 14250, 5, 6, "ORB-AAAA-BBBB-CCCCCC")
	var lines := t.split("\n")
	assert_eq(lines[0], "ORBIT · Daily Orbit · Nov 25", "title line")
	assert_eq(lines[1], "🟣🔵🔴🟣🟡🟢⚫⚫⚫⚫⚫⚫", "ladder: 6 reached of 12")
	assert_eq(lines[2], "Score 14,250 · Chain ×6 · Verdant", "stats")
	assert_eq(lines[3], "Beat me: ORB-AAAA-BBBB-CCCCCC", "challenge")
	assert_eq(ShareText.group(1234567), "1,234,567", "grouping")
	assert_eq(ShareText.group(12), "12", "small numbers")
