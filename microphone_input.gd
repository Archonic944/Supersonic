extends Node

# Audio components
var audio_stream_player: AudioStreamPlayer
var spectrum_analyzer: AudioEffectSpectrumAnalyzer
var audio_effect_capture: AudioEffectCapture

# Frequency band powers (0.0 to 1.0)
var low_band_power: float = 0.0
var mid_band_power: float = 0.0
var high_band_power: float = 0.0

# Smoothing factor for lerping
var lerp_factor: float = 0.1

# Frequency ranges (in Hz)
var low_freq_max: float = 250.0
var mid_freq_max: float = 1500.0
var high_freq_max: float = 20000.0

var low_freq_multiplier: float = 0.8
var mid_freq_multiplier: float = 0.75
var high_freq_multiplier: float = 5.0

# Signals for external components
signal bands_updated(low: float, mid: float, high: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_microphone_input()

func setup_microphone_input() -> void:
	# Create AudioStreamPlayer for microphone input
	audio_stream_player = AudioStreamPlayer.new()
	# Assign to a dedicated 'Record' bus (must exist in project settings)
	audio_stream_player.bus = "Record"
	audio_stream_player.volume_db = -80 # Ensure muted
	add_child(audio_stream_player)

	# Set up microphone stream
	var microphone_stream = AudioStreamMicrophone.new()
	audio_stream_player.stream = microphone_stream

	# Create and add spectrum analyzer effect
	spectrum_analyzer = AudioEffectSpectrumAnalyzer.new()
	spectrum_analyzer.buffer_length = 2.0 # 2 seconds buffer
	spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048

	# Add effect to the 'Record' bus
	var bus_index = AudioServer.get_bus_index("Record")
	AudioServer.add_bus_effect(bus_index, spectrum_analyzer)

	# Start playing to capture microphone input
	audio_stream_player.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	update_frequency_bands()

func update_frequency_bands() -> void:
	if not spectrum_analyzer:
		return

	# Always use the correct bus index for 'Record'
	var bus_index = AudioServer.get_bus_index("Record")
	var spectrum = AudioServer.get_bus_effect_instance(bus_index, 0) as AudioEffectSpectrumAnalyzerInstance
	if not spectrum:
		return

	# Calculate band powers
	var new_low = calculate_band_power(spectrum, 0.0, low_freq_max) * low_freq_multiplier
	var new_mid = calculate_band_power(spectrum, low_freq_max, mid_freq_max) * mid_freq_multiplier
	var new_high = calculate_band_power(spectrum, mid_freq_max, high_freq_max) * high_freq_multiplier
	
	# Debug: print raw band values
	print("[MicrophoneInput] Bands - Low:", new_low, " Mid:", new_mid, " High:", new_high)

	# Smooth the values using lerp
	low_band_power = lerp(low_band_power, new_low, lerp_factor)
	mid_band_power = lerp(mid_band_power, new_mid, lerp_factor)
	high_band_power = lerp(high_band_power, new_high, lerp_factor)
	
	# Emit signal for external listeners
	bands_updated.emit(low_band_power, mid_band_power, high_band_power)

func calculate_band_power(spectrum: AudioEffectSpectrumAnalyzerInstance, freq_min: float, freq_max: float) -> float:
	# Directly get combined magnitude for the frequency range
	var magnitude = spectrum.get_magnitude_for_frequency_range(freq_min, freq_max)
	# Compute power (sum of squares) and apply amplification
	var power = magnitude.x * magnitude.x + magnitude.y * magnitude.y
	return sqrt(power) * 1000000

# Getter methods for external access
func get_low_band_power() -> float:
	return low_band_power

func get_mid_band_power() -> float:
	return mid_band_power

func get_high_band_power() -> float:
	return high_band_power

func get_all_band_powers() -> Vector3:
	return Vector3(low_band_power, mid_band_power, high_band_power)
