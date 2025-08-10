extends Node2D

# References to the progress bars
@onready var low_freq_bar: ProgressBar = $ProgressBar
@onready var mid_freq_bar: ProgressBar = $ProgressBar2
@onready var high_freq_bar: ProgressBar = $ProgressBar3

# Reference to the microphone input node
var microphone_input: Node

# Smoothing factor for visual updates
var visual_lerp_factor: float = 0.15

# Amplitude multipliers for better visual representation
var low_multiplier: float = 1
var mid_multiplier: float = 1
var high_multiplier: float = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_microphone_connection()

func setup_microphone_connection() -> void:
	# Access the MicrophoneInput autoload singleton
	microphone_input = MicrophoneInput
	
	if not microphone_input:
		print("Warning: MicrophoneInput autoload not found!")
		return
	
	# Connect to the bands_updated signal
	if microphone_input.has_signal("bands_updated"):
		if not microphone_input.bands_updated.is_connected(_on_bands_updated):
			microphone_input.bands_updated.connect(_on_bands_updated)
		print("Connected to microphone input signal")
	else:
		print("Warning: bands_updated signal not found on MicrophoneInput")

# Signal handler for frequency band updates
func _on_bands_updated(low: float, mid: float, high: float) -> void:
	update_progress_bars(low, mid, high)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Fallback: directly get values if signal connection failed
	if not microphone_input:
		microphone_input = MicrophoneInput
	
	if microphone_input and microphone_input.has_method("get_all_band_powers"):
		var band_powers = microphone_input.get_all_band_powers()
		update_progress_bars(band_powers.x, band_powers.y, band_powers.z)

func update_progress_bars(low: float, mid: float, high: float) -> void:
	if not low_freq_bar or not mid_freq_bar or not high_freq_bar:
		return
	
	# Apply multipliers and clamp values between 0 and 1
	var target_low = clamp(low * low_multiplier, 0.0, 1.0)
	var target_mid = clamp(mid * mid_multiplier, 0.0, 1.0)
	var target_high = clamp(high * high_multiplier, 0.0, 1.0)

	print(target_low)
	print(target_mid)
	print(target_high)
	
	# Smooth the progress bar updates
	low_freq_bar.value = lerp(low_freq_bar.value, target_low, visual_lerp_factor)
	mid_freq_bar.value = lerp(mid_freq_bar.value, target_mid, visual_lerp_factor)
	high_freq_bar.value = lerp(high_freq_bar.value, target_high, visual_lerp_factor)
