extends Node
## Progresso de níveis do modo campanha (solo). Guarda até onde o jogador já
## desbloqueou e salva isso em disco, igual ao perfil do jogador (PerfilJogador),
## pra não se perder quando o jogo for fechado.

const CAMINHO_SAVE := "user://progresso.save"
const TOTAL_NIVEIS := 8

# Nível 1 já vem liberado. "nivel_maximo_desbloqueado" é o maior nível que o
# jogador já pode jogar (não necessariamente o que ele já venceu).
var nivel_maximo_desbloqueado: int = 1

# Qual nível está sendo jogado agora (definido pela tela de níveis antes de
# entrar na partida). Não precisa ser salvo -- só interessa durante a partida.
var nivel_atual: int = 1


func _ready() -> void:
	carregar()


func nivel_desbloqueado(nivel: int) -> bool:
	return nivel <= nivel_maximo_desbloqueado


func completar_nivel(nivel: int) -> void:
	# Só avança o progresso se o nível concluído for o mais avançado que o
	# jogador tinha liberado (evita "voltar" o progresso ao rejogar uma fase
	# antiga) e se ainda não bateu no fim da campanha.
	if nivel == nivel_maximo_desbloqueado and nivel_maximo_desbloqueado < TOTAL_NIVEIS:
		nivel_maximo_desbloqueado += 1
		salvar()


func salvar() -> void:
	var dados := {
		"nivel_maximo_desbloqueado": nivel_maximo_desbloqueado,
	}
	var arquivo := FileAccess.open(CAMINHO_SAVE, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível salvar o progresso: %s" % FileAccess.get_open_error())
		return
	arquivo.store_string(JSON.stringify(dados))
	arquivo.close()


func carregar() -> void:
	if not FileAccess.file_exists(CAMINHO_SAVE):
		return

	var arquivo := FileAccess.open(CAMINHO_SAVE, FileAccess.READ)
	if arquivo == null:
		return

	var texto := arquivo.get_as_text()
	arquivo.close()

	var resultado = JSON.parse_string(texto)
	if typeof(resultado) != TYPE_DICTIONARY:
		return

	nivel_maximo_desbloqueado = clampi(
		int(resultado.get("nivel_maximo_desbloqueado", 1)),
		1,
		TOTAL_NIVEIS
	)
