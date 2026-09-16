extends CanvasLayer
var pressed = false

func _on_button_pressed() -> void:
	fechar_abrirLoja()

func fechar_abrirLoja():
	if pressed:
		offset.y += 200
		pressed = false
	else:
		offset.y += -200
		pressed = true

@export var atirador_scene: PackedScene
@export var tipo_torre: String = "basica"  # tem que bater com o _custo_da_torre() no NetworkManager

func _on_texture_button_pressed() -> void:
	# FIX: antes chamava NetworkManager.pedir_spawn_torre.rpc_id() direto com
	# 3 argumentos, mas a função só aceitava 2 -- a RPC nunca rodava e nenhuma
	# torre era criada. Agora criamos um PREVIEW local da própria cena da
	# torre (ela já sabe seguir o mouse até o clique, ver atiradores.gd) e é
	# o clique que dispara o pedido de spawn de verdade pro host.
	var preview = atirador_scene.instantiate()
	preview.tipo_torre = tipo_torre
	preview.cena_torre = atirador_scene.resource_path
	get_tree().current_scene.add_child(preview)
	fechar_abrirLoja()
