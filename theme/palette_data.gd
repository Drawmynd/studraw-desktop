class_name PaletteData
extends Resource

enum Colors {
	BACKGROUND,
	SURFACE,
	SURFACE_RAISED,
	BORDER,
	TEXT,
	TEXT_STRONG,
	TEXT_MUTED,
	ACCENT,
	HOVER,
	PRESSED,
	DANGER,
	SUCCESS,
}

@export_group("Surfaces")
@export var background := Color("#171a1f")
@export var surface := Color("#20252d")
@export var surface_raised := Color("#262d38")
@export var border := Color("#3d4759")

@export_group("Text")
@export var text := Color("#d9e0eb")
@export var text_strong := Color("#f2f5fa")
@export var text_muted := Color("#99a3b3")
@export var accent := Color("#f0c674")

@export_group("States")
@export var hover := Color("#334054")
@export var pressed := Color("#3d4a61")
@export var danger := Color("#c04a54")
@export var success := Color("#3f9a63")
