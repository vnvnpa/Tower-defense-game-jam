extends CanvasLayer

## Tela de perfil "completa": mostra quem é o jogador e os números dele
## (ouro atual, abates por tipo de inimigo), com atalho pra editar o
## perfil (nick/idade/cor) e um botão de resetar TODO o progresso.

const CENA_OPCOES := "res://cenas/menus/opcoes.tscn"
const CENA_EDITAR_PERFIL := "res://cenas/menus/perfil.tscn"

const TEXTO_RESETAR_PADRAO := "Resetar tudo"
const TEXTO_RESETAR_CONFIRMAR := "Tem certeza? Clique de novo pra confirmar"
const TEMPO_CONFIRMACAO := 4.0

@onready var label_nick: Label = $MarginContainer/VBoxContainer/LabelNick
@onready var label_ouro: Label = $MarginContainer/VBoxContainer/LabelOuro
@onready var label_comuns: Label = $MarginContainer/VBoxContainer/LabelComuns
@onready var label_raros: Label = $MarginContainer/VBoxContainer/LabelRaros
@onready var label_rimuru: Label = $MarginContainer/VBoxContainer/LabelRimuru

@onready var botao_editar_perfil: Button = $MarginContainer/VBoxContainer/EditarPerfil
@onready var botao_resetar: Button = $MarginContainer/VBoxContainer/ResetarTudo
@onready var botao_voltar: Button = $MarginContainer/VBoxContainer/Voltar

var _aguardando_confirmacao_reset: bool = false


func _ready() -> void:
	get_tree().paused = false

	botao_editar_perfil.pressed.connect(_on_editar_perfil_pressed)
	botao_resetar.pressed.connect(_on_resetar_pressed)
	botao_voltar.pressed.connect(_on_voltar_pressed)

	_atualizar_dados()


func _atualizar_dados() -> void:
	label_nick.text = (
		PerfilJogador.nick if PerfilJogador.nick != "" else "(sem nick)"
	)

	label_ouro.text = "Ouro atual: %d" % ControleDeTudo.coin

	label_comuns.text = "Slimes comuns derrotados: %d" % Progresso.slimes_comuns_derrotados
	label_raros.text = "Slimes raros derrotados: %d" % Progresso.slimes_raros_derrotados
	label_rimuru.text = "Rimurus derrotados: %d" % Progresso.rimurus_derrotados


func _on_editar_perfil_pressed() -> void:
	PerfilJogador.forcar_tela = true
	get_tree().change_scene_to_file(CENA_EDITAR_PERFIL)


func _on_resetar_pressed() -> void:
	if not _aguardando_confirmacao_reset:
		# Primeiro clique: só avisa, não faz nada ainda.
		_aguardando_confirmacao_reset = true
		botao_resetar.text = TEXTO_RESETAR_CONFIRMAR

		await get_tree().create_timer(TEMPO_CONFIRMACAO).timeout

		# Ninguém confirmou a tempo -- volta ao normal.
		if _aguardando_confirmacao_reset:
			_aguardando_confirmacao_reset = false
			botao_resetar.text = TEXTO_RESETAR_PADRAO

		return

	# Segundo clique dentro do tempo: reseta de verdade.
	_aguardando_confirmacao_reset = false
	botao_resetar.text = TEXTO_RESETAR_PADRAO

	Progresso.resetar_tudo()

	_atualizar_dados()


func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file(CENA_OPCOES)
