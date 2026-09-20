extends Node

# ============================================================
# PerfilJogador - Autoload com os dados do jogador (nick, idade, cor
# favorita). Fica salvo em disco (user://) pra sobreviver a fechar e
# abrir o jogo de novo -- só pergunta uma vez, na primeira execução.
# ============================================================

const CAMINHO_SAVE := "user://perfil.save"

var nick := ""
var idade := 0
var cor_favorita := Color(1, 1, 1) # branco = "sem cor escolhida ainda" (não tinge nada)

# Ligado pela tela de menu quando o jogador clica em "Editar perfil",
# pra forçar o formulário aparecer de novo mesmo já tendo perfil salvo.
var forcar_tela := false


func _ready() -> void:
	carregar()
	if nick != "":
		NetworkManager.definir_nick(nick)


func tem_perfil_salvo() -> bool:
	return nick != ""


func salvar(novo_nick: String, nova_idade: int, nova_cor: Color) -> void:
	var limpo := novo_nick.strip_edges()
	if limpo.length() > 16:
		limpo = limpo.substr(0, 16)
	nick = limpo
	idade = nova_idade
	cor_favorita = nova_cor

	var dados := {
		"nick": nick,
		"idade": idade,
		"cor_favorita": cor_favorita.to_html(false),
	}

	var arquivo := FileAccess.open(CAMINHO_SAVE, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não consegui salvar o perfil: %s" % FileAccess.get_open_error())
		return
	arquivo.store_string(JSON.stringify(dados))
	arquivo.close()

	NetworkManager.definir_nick(nick)


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

	nick = str(resultado.get("nick", ""))
	idade = int(resultado.get("idade", 0))

	var cor_texto: String = str(resultado.get("cor_favorita", "ffffffff"))
	cor_favorita = Color(cor_texto)
