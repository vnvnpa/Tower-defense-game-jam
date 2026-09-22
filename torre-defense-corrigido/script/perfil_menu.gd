extends CanvasLayer

@onready var campo_nick: LineEdit = $VBoxContainer/CampoNick
@onready var campo_idade: SpinBox = $VBoxContainer/HBoxIdade/CampoIdade
@onready var campo_cor: ColorPickerButton = $VBoxContainer/HBoxCor/CampoCor
@onready var botao_continuar: Button = $VBoxContainer/BotaoContinuar
@onready var label_erro: Label = $VBoxContainer/LabelErro

const CENA_MENU := "res://cenas/menus/menu.tscn"


func _ready() -> void:
	get_tree().paused = false
	botao_continuar.pressed.connect(_on_continuar_pressed)
	label_erro.text = ""

	var editando := PerfilJogador.forcar_tela
	PerfilJogador.forcar_tela = false

	# Já existe perfil salvo e não foi pedido pra editar -- pula direto pro
	# menu, sem perguntar de novo.
	if PerfilJogador.tem_perfil_salvo() and not editando:
		get_tree().call_deferred("change_scene_to_file",CENA_MENU)
		return

	if PerfilJogador.tem_perfil_salvo():
		# Editando um perfil que já existe: pré-preenche com os dados atuais.
		campo_nick.text = PerfilJogador.nick
		campo_idade.value = PerfilJogador.idade
		campo_cor.color = PerfilJogador.cor_favorita
	else:
		# Primeira vez no jogo: valores padrão razoáveis.
		campo_idade.value = 10
		campo_cor.color = Color(0.2, 0.6, 1.0)
		ColorPicker.color = ColorPicker.color * 5.0

func _on_continuar_pressed() -> void:
	var nick := campo_nick.text.strip_edges()
	if nick == "":
		label_erro.text = "Digite um nick antes de continuar!"
		return

	PerfilJogador.salvar(nick, int(campo_idade.value), campo_cor.color)
	get_tree().change_scene_to_file(CENA_MENU)
