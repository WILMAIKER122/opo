extends Control

@onready var player: Player = $"../.."
var bot:bool= true
const MAGICO = preload("uid://custue6v05y35")
const NORMAL = preload("uid://cvvbnimy5twnr")
@onready var vida_2: TextureProgressBar = $VBoxContainer/vida2
@onready var hambre_2: TextureProgressBar = $VBoxContainer/hambre2

var ver:bool

func _ready() -> void:
	vida_2.max_value = player.estadisticas.vida
	hambre_2.max_value = player.estadisticas.hambre.hambre_maxima

func _process(_delta: float) -> void:
	hambre_2.value = player.estadisticas.hambre.hambre_actual


func _on_button_pressed() -> void:
	if ver:
		$inventario.visible=false
		ver = false
		return
	else:
		$inventario.visible=true
		ver = true
		return
