extends CharacterBody2D

@export var thrust_power: float = 300.0 # speed units per second at full throttle
@export var turn_speed: float = 2.5 # radians/sec at full difference
@export var max_tilt_deg: float = 40.0 # tilt limit from neutral
@export var friction_per_second: float = 10.0
@export var braking_power: float = 500.0

# Health setup
@export var max_hp: int = 6
var hp: int
var is_dead: bool = false
var death_timer: float = 0.0
@export var death_duration: float = 1.0

var flame_thresholds := [0.2, 0.45, 0.7, 0.9]

var neutral_angle: float

func _ready() -> void:
	neutral_angle = rotation
	# Initialize health
	hp = max_hp
	
	# Create death effect overlay
	if not has_node("Camera2D/DeathOverlay"):
		var overlay = ColorRect.new()
		overlay.name = "DeathOverlay"
		overlay.color = Color(1, 0, 0, 0) # Red with 0 alpha initially
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.size = Vector2(1920, 1080) # Make it large enough for screen
		overlay.visible = false
		$Camera2D.add_child(overlay)

func _physics_process(delta: float) -> void:
	# Death animation handling
	if is_dead:
		death_timer += delta
		var overlay = $Camera2D/DeathOverlay
		overlay.visible = true
		# Pulse the overlay alpha
		var pulse = sin(death_timer * 10) * 0.3 + 0.5
		overlay.color.a = pulse
		
		# Reset scene after death_duration
		if death_timer >= death_duration:
			get_tree().reload_current_scene()
		return
		
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

	# Handle collisions with asteroids
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.has_meta("material") and collider.get_meta("material") == "asteroid":
			var cs = collider.get_node("CollisionShape2D")
			if cs.disabled:
				continue
			# Reduce health
			hp -= 1
			get_tree().current_scene.get_node("CanvasLayer/Visualizer/RichTextLabel").text = str(hp) + "/" + str(max_hp)
			
			# Check if player died
			if hp <= 0 and !is_dead:
				die()
				return
				
			# Disable asteroid collision and play break animation
			cs.disabled = true
			var ap = collider.get_node("AnimationPlayer")
			ap.play("break")
			if not ap.is_connected("animation_finished", _on_asteroid_animation_finished):
				ap.connect("animation_finished", _on_asteroid_animation_finished.bind("break", collider))

# Called when an asteroid finishes its break animation
func _on_asteroid_animation_finished(anim_name: String, asteroid: Node) -> void:
	if anim_name == "break":
		asteroid.queue_free()
		
# Called when player health reaches zero
func die() -> void:
	is_dead = true
	death_timer = 0.0
	velocity = Vector2.ZERO
	# Make ship stop responding to collisions
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Play death sound if available
	if get_tree().current_scene.has_node("DeathSoundEffect"):
		var death_sound = get_tree().current_scene.get_node("DeathSoundEffect")
		if death_sound is AudioStreamPlayer:
			death_sound.play()
	
	# Flash the overlay red
	$Camera2D/DeathOverlay.visible = true
