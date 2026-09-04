class_name UiFx
extends RefCounted


static func punch(button: Control, sfx_name: String = "ui_click") -> void:
	Sfx.play(sfx_name)
	button.pivot_offset = button.size / 2.0
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.88, 0.88), 0.04) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
