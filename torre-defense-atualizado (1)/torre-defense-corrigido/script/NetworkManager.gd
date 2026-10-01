extends Node

## A camada de rede (ENetMultiplayerPeer, RPCs, MultiplayerSpawner
## autoritativo) foi removida do projeto por estar pesada demais. Este
## autoload virou um gerenciador de estado LOCAL: guarda o modo de jogo,
## a velocidade da partida e a "lista de jogadores" (só você) que o lobby
## usa pra exibir.
##
## Sem um MultiplayerPeer configurado, `multiplayer.is_server()` sempre
## retorna true, então o fluxo de "criar servidor -> lobby -> escolher
## modo -> pronto" continua funcionando sozinho, 100% offline. Só entrar
## numa sala pelo IP/código não funciona mais de verdade, porque isso
## exigiria uma conexão de rede real -- por isso essas funções avisam
## falha em vez de travar o jogo.

signal conectado_ao_servidor
signal conexao_falhou
signal codigo_nao_encontrado
signal servidor_criado
signal lista_jogadores_atualizada
signal modo_de_jogo_atualizado(modo: String)
signal partida_iniciada
signal jogador_desconectou(id: int)
signal perdeu_conexao
signal velocidade_jogo_atualizada(velocidade: float)

var nick: String = ""
var modo_de_jogo: String = "classico"
var velocidade_jogo: float = 1.0
var codigo_sala: String = "OFFLINE"
var jogadores: Dictionary = {}

const CENAS_DOS_MODOS := {
	"classico": "res://cenas/modos/primaria_classico.tscn",
	"rapido": "res://cenas/modos/primaria_rapido.tscn",
	"so_rimuru": "res://cenas/modos/primaria_so_rimuru.tscn",
	"infinito": "res://cenas/modos/primaria_infinito.tscn",
	"sobrevivencia": "res://cenas/modos/primaria_sobrevivencia.tscn",
	"corrida": "res://cenas/modos/primaria_corrida.tscn",
}


func definir_nick(novo_nick: String) -> void:
	nick = novo_nick
	jogadores[1] = nick if nick != "" else "Jogador"
	lista_jogadores_atualizada.emit()


func definir_velocidade_local(velocidade: float) -> void:
	velocidade_jogo = velocidade
	Engine.time_scale = velocidade
	velocidade_jogo_atualizada.emit(velocidade_jogo)


func definir_modo_de_jogo(modo: String) -> void:
	modo_de_jogo = modo
	modo_de_jogo_atualizado.emit(modo_de_jogo)


func cena_do_modo() -> String:
	return CENAS_DOS_MODOS.get(modo_de_jogo, "res://cenas/primaria.tscn")


func criar_servidor() -> void:
	# Sem rede real: "criar servidor" te leva direto pro lobby, já como
	# host sozinho na sala (offline).
	codigo_sala = "OFFLINE"
	jogadores.clear()
	jogadores[1] = nick if nick != "" else "Jogador"
	lista_jogadores_atualizada.emit()
	servidor_criado.emit()


func entrar_servidor(_ip: String) -> void:
	# Conectar por IP dependia do ENetMultiplayerPeer, removido do projeto.
	conexao_falhou.emit()


func entrar_por_codigo(_codigo: String) -> void:
	# Idem: descoberta por broadcast UDP dependia da camada de rede removida.
	codigo_nao_encontrado.emit()


func iniciar_partida() -> void:
	partida_iniciada.emit()


func desconectar() -> void:
	jogadores.clear()
	codigo_sala = "OFFLINE"


# Distância mínima entre os CENTROS de duas torres pra não deixar
# colocar uma em cima (ou quase em cima) da outra.
const DISTANCIA_MINIMA_ENTRE_TORRES: float = 45.0


func posicao_torre_valida(pos_global: Vector2, ignorar: Node = null) -> bool:
	# Regra 1: não pode colocar torre a menos de 55px do caminho dos inimigos.
	var laco := Engine.get_main_loop()
	if not (laco is SceneTree):
		return true
	var arvore := laco as SceneTree
	var cena := arvore.current_scene
	if cena == null:
		return true

	var caminho := cena.find_child("Path2D", true, false)
	if caminho != null and caminho is Path2D and (caminho as Path2D).curve != null:
		var caminho_2d := caminho as Path2D
		var pos_local_caminho: Vector2 = caminho_2d.to_local(pos_global)
		var mais_proxima: Vector2 = caminho_2d.curve.get_closest_point(pos_local_caminho)
		if pos_local_caminho.distance_to(mais_proxima) < 55.0:
			return false

	# Regra 2: não pode colocar torre em cima de um tile do grupo global
	# "areaComCoisa" (decoração/obstáculo). Isso NÃO dependia de colisão
	# nenhuma -- o TileSet dessas camadas não tem physics layer configurada
	# -- então a checagem é feita direto na célula do tile (get_cell_source_id),
	# olhando todo TileMapLayer que esteja nesse grupo, em vez de esperar
	# uma Area2D/colisão que nunca existiu.
	for camada in arvore.get_nodes_in_group("areaComCoisa"):
		if camada is TileMapLayer:
			var tile_layer := camada as TileMapLayer
			var pos_local_tile: Vector2 = tile_layer.to_local(pos_global)
			var celula: Vector2i = tile_layer.local_to_map(pos_local_tile)
			if tile_layer.get_cell_source_id(celula) != -1:
				return false

	# Regra 3: não pode colocar torre em cima (nem muito perto) de outra
	# torre já colocada. Cada torre tem uma Area2D "areaDeReceberB=" no
	# grupo global "torres" -- usamos o nó PAI dela (a torre em si) pra
	# medir a distância pela posição global.
	for area in arvore.get_nodes_in_group("torres"):
		if area is Area2D:
			var torre := area.get_parent()
			if torre == ignorar:
				# É a própria torre que está sendo arrastada/colocada
				# agora -- não conta contra ela mesma.
				continue
			if torre is Node2D and (torre as Node2D).global_position.distance_to(pos_global) < DISTANCIA_MINIMA_ENTRE_TORRES:
				return false

	return true
