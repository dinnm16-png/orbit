class_name ChallengeCode
extends RefCounted
## "Beat my orbit" codes: a short code that carries everything needed to replay
## the exact same game — mode, planet sequence (seed), difficulty — plus the
## score to beat. No server: the code IS the challenge.
##
## Layout (70 bits): version 2 | mode 4 | difficulty 2 | seed 32 | score 24 | check 6
## Written in Crockford base32 (no I, L, O, U: hard to misread), grouped like
## ORB-K7Q2-M9XD-4A6.

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const VERSION := 1
## Modes that can be challenged, by index (order is part of the format: append only).
const MODES := ["classic", "zen", "daily", "blitz", "collapse", "limited", "binary"]
const MAX_SCORE := (1 << 24) - 1


## Returns "" if the mode can't be challenged (e.g. puzzles).
static func encode(mode_id: String, seed: int, difficulty: int, score: int) -> String:
	var mode_index := MODES.find(mode_id)
	if mode_index < 0:
		return ""
	var bits := []  # Most significant first.
	_push(bits, VERSION, 2)
	_push(bits, mode_index, 4)
	_push(bits, clampi(difficulty, 0, 3), 2)
	_push(bits, seed & 0xFFFFFFFF, 32)
	_push(bits, clampi(score, 0, MAX_SCORE), 24)
	_push(bits, _checksum(bits), 6)
	var chars := ""
	for i in range(0, bits.size(), 5):
		var v := 0
		for j in 5:
			v = (v << 1) | bits[i + j]
		chars += ALPHABET[v]
	# ORB-XXXX-XXXX-XXXXXX (14 characters after the prefix).
	return "ORB-%s-%s-%s" % [chars.substr(0, 4), chars.substr(4, 4), chars.substr(8)]


## Parses a code (any case, with or without dashes/spaces/prefix).
## Returns {} if invalid, else {"mode", "seed", "difficulty", "score"}.
static func decode(text: String) -> Dictionary:
	var clean := text.strip_edges().to_upper()
	# Accept a whole pasted message ("Beat me: ORB-...") by taking what follows ORB.
	var at := clean.rfind("ORB")
	if at >= 0:
		clean = clean.substr(at + 3)
	clean = clean.replace(" ", "").replace("-", "").replace("\n", "").strip_edges()
	# Accept common misreadings.
	clean = clean.replace("O", "0").replace("I", "1").replace("L", "1")
	if clean.length() != 14:
		return {}
	var bits := []
	for ch in clean:
		var v := ALPHABET.find(ch)
		if v < 0:
			return {}
		for j in range(4, -1, -1):
			bits.append((v >> j) & 1)
	var payload := bits.slice(0, 64)
	if _read(bits, 64, 6) != _checksum(payload):
		return {}
	if _read(bits, 0, 2) != VERSION:
		return {}
	var mode_index := _read(bits, 2, 4)
	if mode_index >= MODES.size():
		return {}
	return {
		"mode": MODES[mode_index],
		"difficulty": _read(bits, 6, 2),
		"seed": _read(bits, 8, 32),
		"score": _read(bits, 40, 24),
	}


static func _push(bits: Array, value: int, width: int) -> void:
	for i in range(width - 1, -1, -1):
		bits.append((value >> i) & 1)


static func _read(bits: Array, start: int, width: int) -> int:
	var v := 0
	for i in width:
		v = (v << 1) | bits[start + i]
	return v


## 6-bit checksum: catches typos (a wrong or swapped character).
static func _checksum(bits: Array) -> int:
	var h := 0x2B
	for i in bits.size():
		h = (h * 31 + bits[i] * (i + 7)) % 64
	return h
