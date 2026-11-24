extends "res://tests/test_case.gd"


func test_gravity_points_toward_center() -> void:
	var a := OrbitPhysics.gravity_acceleration(Vector2(100, 0), Vector2.ZERO, 50.0)
	assert_vec_almost(a, Vector2(-50, 0), 0.001, "gravity should point at the center")


func test_gravity_has_constant_magnitude() -> void:
	var near := OrbitPhysics.gravity_acceleration(Vector2(10, 0), Vector2.ZERO, 900.0)
	var far := OrbitPhysics.gravity_acceleration(Vector2(0, 5000), Vector2.ZERO, 900.0)
	assert_almost(near.length(), 900.0, 0.01, "near magnitude")
	assert_almost(far.length(), 900.0, 0.01, "far magnitude")


func test_gravity_is_zero_at_center() -> void:
	var a := OrbitPhysics.gravity_acceleration(Vector2(3, 4), Vector2(3, 4), 900.0)
	assert_eq(a, Vector2.ZERO, "no NaN / no force exactly at the center")


func test_clamp_velocity_limits_speed_and_keeps_direction() -> void:
	var v := OrbitPhysics.clamp_velocity(Vector2(3000, 4000), 1000.0)
	assert_almost(v.length(), 1000.0, 0.01, "speed capped")
	assert_vec_almost(v.normalized(), Vector2(0.6, 0.8), 0.0001, "direction kept")
	var slow := OrbitPhysics.clamp_velocity(Vector2(10, 0), 1000.0)
	assert_eq(slow, Vector2(10, 0), "slow velocity untouched")


func test_short_drag_cancels_launch() -> void:
	var v := OrbitPhysics.launch_velocity(Vector2(0, 10), 28.0, 280.0, 1000.0)
	assert_eq(v, Vector2.ZERO, "drag below minimum should cancel")


func test_launch_goes_opposite_to_finger_pull() -> void:
	# Finger moved DOWN by 140 px -> pull vector (start - current) points UP.
	var pull := Vector2(0, 0) - Vector2(0, 140)
	var v := OrbitPhysics.launch_velocity(pull, 28.0, 280.0, 1000.0)
	assert_vec_almost(v, Vector2(0, -500), 0.01, "half pull = half speed, upward")


func test_launch_power_is_capped() -> void:
	var v := OrbitPhysics.launch_velocity(Vector2(5000, 0), 28.0, 280.0, 1000.0)
	assert_almost(v.length(), 1000.0, 0.01, "over-pulling never exceeds max speed")


func test_mass_grows_with_area() -> void:
	assert_almost(OrbitPhysics.mass_for_radius(24.0, 24.0), 1.0)
	assert_almost(OrbitPhysics.mass_for_radius(48.0, 24.0), 4.0)
