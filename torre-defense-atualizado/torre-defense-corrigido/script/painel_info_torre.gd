extends PanelContainer

signal confirmar_pressionado
signal cancelar_pressionado
signal remover_pressionado

@onready var label_titulo: Label = $Margem/Caixa/Titulo
@onready var label_info: Label = $Margem/Caixa/Info
@onready var botao_confirmar: Button = $Margem/Caixa/Botoes/Confirmar
@onready var botao_cancelar: Button = $Margem/Caixa/Botoes/Cancelar
@onready var botao_remover: Button = $Margem/Caixa/Botoes/Remover


func _ready() -> void:
	# top_level: o painel não deve herdar a rotação da torre (importante
	# pro Irrigador, que fica girando sem parar) nem sair da tela quando
	# a torre se move -- ele controla a própria posição em coordenadas
	# globais depois de instanciado (ver atiradores.gd).
	top_level = true
	z_index = 100

	botao_confirmar.pressed.connect(func(): confirmar_pressionado.emit())
	botao_cancelar.pressed.connect(func(): cancelar_pressionado.emit())
	botao_remover.pressed.connect(func(): remover_pressionado.emit())


func configurar(
	titulo: String,
	info: String,
	texto_confirmar: String,
	mostrar_cancelar: bool = true,
	texto_cancelar: String = "Cancelar",
	mostrar_remover: bool = false
) -> void:
	label_titulo.text = titulo
	label_info.text = info
	botao_confirmar.text = texto_confirmar
	botao_cancelar.visible = mostrar_cancelar
	botao_cancelar.text = texto_cancelar
	botao_remover.visible = mostrar_remover
