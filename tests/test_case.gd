extends RefCounted
## Minimal base class for tests. Extend it and add methods starting with "test_".
## Methods may be coroutines (use `await`) for tests that need physics frames.

var tree: SceneTree
var failures: PackedStringArray = PackedStringArray()


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		fail("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func assert_almost(actual: float, expected: float, epsilon: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > epsilon:
		fail("%s (expected %s ± %s, got %s)" % [message, expected, epsilon, actual])


func assert_vec_almost(actual: Vector2, expected: Vector2, epsilon: float = 0.001, message: String = "") -> void:
	if actual.distance_to(expected) > epsilon:
		fail("%s (expected %s, got %s)" % [message, expected, actual])


func wait_physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
