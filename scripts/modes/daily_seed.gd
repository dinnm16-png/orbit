class_name DailySeed
extends RefCounted
## Deterministic daily seeds: every player gets the same planets on the same
## (local) calendar day, with no server. String.hash() is the same on every
## platform, so the seed is too.


static func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return date_key(d["year"], d["month"], d["day"])


static func date_key(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]


static func seed_for(key: String) -> int:
	# SHA-256 spreads similar inputs far apart: consecutive dates have nearly
	# identical String.hash() values, and an earlier version (hash | 1) even
	# gave two consecutive days the SAME seed. Same on every platform.
	var seed := ("orbit-daily-" + key).sha256_text().substr(0, 8).hex_to_int() & 0x7FFFFFFF
	return seed if seed != 0 else 1  # 0 means "random" in Main.


## Human-friendly label, e.g. "Nov 24".
static func pretty(key: String) -> String:
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var parts := key.split("-")
	if parts.size() != 3:
		return key
	return "%s %d" % [months[clampi(int(parts[1]) - 1, 0, 11)], int(parts[2])]
