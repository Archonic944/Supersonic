extends CharacterBody2D

@export var thrust_power: float = 300.0 # speed units per second at full throttle
@export var turn_speed: float = 2.5 # radians/sec at full difference
@export var max_tilt_deg: float = 40.0 # tilt limit from neutral
@export var friction_per_second: float = 10.0
@export var braking_power: float = 500.0

var flame_thresholds := [0.2, 0.45, 0.7, 0.9]

var neutral_angle: float

func _ready() -> void:
	neutral_angle = rotation

func _physics_process(delta: float) -> void:
	# Audio band input
	var left_turn = MicrophoneInput.get_low_band_power()
	var right_turn = MicrophoneInput.get_high_band_power()
	var forward_thrust = MicrophoneInput.get_mid_band_power()
	var brake = forward_thrust

	# --- Visuals ---
	var thrust_frame = int(clamp(forward_thrust, 0.0, 1.0) * (flame_thresholds.size() - 1))
	$Ship/FireRight.frame = thrust_frame

	var left_angle = lerp(deg_to_rad(32), deg_to_rad(-90), clamp(left_turn, 0.0, 1.0))
	$Ship/LeftFin.rotation = left_angle

	# Right turn rotates Ship/RightFin from -32˚ to 90˚
	var right_angle = lerp(deg_to_rad(-32), deg_to_rad(90), clamp(right_turn, 0.0, 1.0))
	$Ship/RightFin.rotation = right_angle

	# Calculate desired rotation change
	var tilt_offset = wrapf(rotation - neutral_angle, -PI, PI)
	var max_tilt = deg_to_rad(max_tilt_deg)

	var diff = right_turn - left_turn

	# Only turn if we aren't at the tilt limit in that direction
	if tilt_offset <= -max_tilt and diff < 0:
		diff = 0 # trying to turn further left at left limit
	elif tilt_offset >= max_tilt and diff > 0:
		diff = 0 # trying to turn further right at right limit

	rotation += diff * turn_speed * delta
	rotation = clamp(rotation, neutral_angle - max_tilt, neutral_angle + max_tilt)

	# Forward motion in facing direction
	if forward_thrust > 0:
		var fwd = Vector2.UP.rotated(rotation)
		velocity = fwd * (forward_thrust * thrust_power)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, delta * friction_per_second)
	if brake > 0:
		velocity = velocity.move_toward(Vector2.ZERO, delta * braking_power * brake)

	move_and_slide()
