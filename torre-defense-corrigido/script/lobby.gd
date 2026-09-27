extends CanvasLayer

@onready var lista_jogadores: ItemList = $VBoxContainer/ListaJogadores
@onready var opcoes_modo: OptionButton = $VBoxContainer/HBoxModo/OpcoesModo
@onready var botao_pronto: Button = $VBoxContainer/BotaoPronto
@onready var botao_voltar: Button = $VBoxContainer/BotaoVoltar
@onready var label_status: Label = $VBoxContainer/LabelStatus
@onready var label_codigo: Label = $VBoxContainer/LabelCodigo
@onready var caixa_principal: VBoxContainer = $VBoxContainer
@onready var label_descricao_modo: Label = $VBoxContainer/LabelDescricaoModo

const CENA_DO_JOGO := "res://cenas/primaria.tscn"
const CENA_MENU_MULTIPLAYER := "res://cenas/menus/menumultiplayer.tscn"

# Precisa bater com o que primaria.gd sabe interpretar em _aplicar_modo_de_jogo()
var modos := ["classico", "rapido", "so_rimuru", "infinito", "sobrevivencia", "corrida"]
var nomes_modos := [
	"Clássico",
	"Rápido",
	"Só Rimuru",
	"Infinito",
	"Sobrevivência",
	"Corrida"
]
var descricoes_modos := [
	"10 rodadas, ritmo padrão e economia normal.",
	"20 rodadas, mais inimigos e intervalos menores.",
	"Somente Rimuru aparece como inimigo. Economia própria.",
	"Sem fim: a quantidade de inimigos aumenta com as rodadas.",
	"Pressão constante, muitas unidades e partidas longas.",
	"10 rodadas em ritmo acelerado, com mais inimigos."
]


func _ready() -> void:
	get_tree().paused = false

	var sou_host := multiplayer.is_server()

	for nome in nomes_modos:
		opcoes_modo.add_item(nome)
	var indice_atual := modos.find(NetworkManager.modo_de_jogo)
	opcoes_modo.selected = maxi(indice_atual, 0)
	_atualizar_descricao_modo(opcoes_modo.selected)

	# Só o host escolhe o modo e aperta "pronto"; os clientes só acompanham.
	opcoes_modo.disabled = not sou_host
	botao_pronto.visible = sou_host
	botao_pronto.text = "Pronto (trava a sala e começa)"

	opcoes_modo.item_selected.connect(_on_modo_selecionado)
	botao_pronto.pressed.connect(_on_pronto_pressed)
	botao_voltar.pressed.connect(_on_voltar_pressed)

	NetworkManager.lista_jogadores_atualizada.connect(_atualizar_lista)
	NetworkManager.modo_de_jogo_atualizado.connect(_on_modo_atualizado)
	NetworkManager.partida_iniciada.connect(_on_partida_iniciada)
	NetworkManager.jogador_desconectou.connect(_on_jogador_saiu)
	NetworkManager.perdeu_conexao.connect(_on_perdeu_conexao)

	_atualizar_lista()
	if not sou_host:
		label_status.text += "\nAguardando o host começar..."

	label_codigo.text = "Código da sala: %s" % NetworkManager.codigo_sala
	caixa_principal.modulate = PerfilJogador.cor_favorita


func _atualizar_lista() -> void:
	lista_jogadores.clear()
	for id in NetworkManager.jogadores.keys():
		var nome: String = NetworkManager.jogadores[id]
		if id == multiplayer.get_unique_id():
			nome += " (você)"
		lista_jogadores.add_item(nome)
	label_status.text = "%d jogador(es) na sala" % NetworkManager.jogadores.size()
	label_codigo.text = "Código da sala: %s" % NetworkManager.codigo_sala


func _on_modo_selecionado(indice: int) -> void:
	_atualizar_descricao_modo(indice)
	if not multiplayer.is_server():
		return
	NetworkManager.definir_modo_de_jogo(modos[indice])


func _on_modo_atualizado(modo: String) -> void:
	var indice := modos.find(modo)
	if indice != -1:
		opcoes_modo.selected = indice
		label_descricao_modo.text = descricoes_modos[indice]

func _atualizar_descricao_modo(indice: int) -> void:
	if indice >= 0 and indice < descricoes_modos.size():
		label_descricao_modo.text = descricoes_modos[indice]


func _on_pronto_pressed() -> void:
	if not multiplayer.is_server():
		return
	NetworkManager.iniciar_partida()


func _on_partida_iniciada() -> void:
	get_tree().change_scene_to_file(NetworkManager.cena_do_modo())


func _on_jogador_saiu(_id: int) -> void:
	# a lista já é atualizada via lista_jogadores_atualizada; isso é só
	# um gancho caso a gente queira mostrar um aviso de "fulano saiu" depois.
	pass


func _on_voltar_pressed() -> void:
	NetworkManager.desconectar()
	get_tree().change_scene_to_file(CENA_MENU_MULTIPLAYER)


func _on_perdeu_conexao() -> void:
	# Servidor caiu de verdade (não fui eu que saí) -- não faz sentido
	# deixar o cliente preso numa sala morta, então volta pro menu sozinho.
	get_tree().change_scene_to_file(CENA_MENU_MULTIPLAYER)
