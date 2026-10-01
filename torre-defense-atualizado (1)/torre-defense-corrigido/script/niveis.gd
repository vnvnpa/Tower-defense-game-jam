extends CanvasLayer

const CENA_DO_JOGO := "res://cenas/primaria.tscn"  # fallback, não deveria ser usado
const CENA_MENU_MULTIPLAYER := "res://cenas/menus/menumultiplayer.tscn"
const CENA_EVOLUCAO := "res://cenas/menus/evolucao.tscn"

# Cada nível agora é uma cena própria (cenas/niveis/nivel_N.tscn), pra você
# poder editar o cenário e os pesos dos inimigos de cada uma separadamente
# no editor, sem mexer em código.
const CENAS_DOS_NIVEIS := {
	1: "res://cenas/niveis/nivel_1.tscn",
	2: "res://cenas/niveis/nivel_2.tscn",
	3: "res://cenas/niveis/nivel_3.tscn",
	4: "res://cenas/niveis/nivel_4.tscn",
	5: "res://cenas/niveis/nivel_5.tscn",
	6: "res://cenas/niveis/nivel_6.tscn",
	7: "res://cenas/niveis/nivel_7.tscn",
	8: "res://cenas/niveis/nivel_8.tscn",
}

@onready var grid: GridContainer = $MarginContainer/VBoxContainer/GridNiveis
@onready var botao_voltar: Button = $MarginContainer/VBoxContainer/HBoxBotoes/Voltar
@onready var botao_evolucao: Button = $MarginContainer/VBoxContainer/HBoxBotoes/Evolucao


func _ready() -> void:
	get_tree().paused = false
	botao_voltar.pressed.connect(_on_voltar_pressed)
	botao_evolucao.pressed.connect(_on_evolucao_pressed)
	_montar_grid()


func _montar_grid() -> void:
	for filho in grid.get_children():
		filho.queue_free()

	for n in range(1, Progresso.TOTAL_NIVEIS + 1):
		var botao := Button.new()
		botao.custom_minimum_size = Vector2(150, 70)

		if Progresso.nivel_desbloqueado(n):
			botao.text = "Nível %d" % n
			botao.pressed.connect(_on_nivel_pressed.bind(n))
		else:
			botao.text = "Nível %d\n(bloqueado)" % n
			botao.disabled = true

		grid.add_child(botao)


func _on_nivel_pressed(nivel: int) -> void:
	Progresso.nivel_atual = nivel
	# "campanha" avisa a primaria.gd pra NÃO sobrescrever total_rodadas,
	# quantidade de inimigos etc. -- cada nível usa os valores que você
	# ajustar diretamente no Inspector daquela cena.
	NetworkManager.modo_de_jogo = "campanha"
	NetworkManager.definir_velocidade_local(1.0)

	# Garante moeda/vida/água zerados e já com os bônus de evolução
	# permanente aplicados antes de entrar na fase.
	ControleDeTudo.resetar_estado_local()

	get_tree().change_scene_to_file(CENAS_DOS_NIVEIS.get(nivel, CENA_DO_JOGO))


func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file(CENA_MENU_MULTIPLAYER)


func _on_evolucao_pressed() -> void:
	get_tree().change_scene_to_file(CENA_EVOLUCAO)
