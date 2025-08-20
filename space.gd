extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CanvasLayer/Visualizer/RichTextLabel.text = str($Spaceship.max_hp) + "/" + str($Spaceship.max_hp)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if $Finish.overlaps_body($Spaceship):
		get_tree().change_scene_to_file("res://win_screen.tscn")
		
