# Torre Defense - modos de jogo e velocidade

## O que foi adicionado nesta versão

### 1. Velocidade da partida
- O botão de velocidade aparece **somente para o host** durante a partida.
- Estado normal: **1x**.
- Primeiro clique: **2x**.
- Segundo clique: volta para **1x**.
- A velocidade é sincronizada para todos os jogadores usando `Engine.time_scale`.
- Inimigos, torres, animações e `Timer`s acompanham a mesma velocidade.
- Ao iniciar uma nova partida ou desconectar, a velocidade volta para 1x.
- O cliente não consegue alterar a velocidade porque a RPC que muda o estado só aceita a autoridade do servidor.

Arquivo principal:
- `script/controle_velocidade.gd`
- lógica de rede: `script/NetworkManager.gd`

### 2. Modos no lobby

O host escolhe o modo no lobby. Os clientes apenas acompanham a escolha.

| Modo | Funcionamento | Dinheiro inicial |
|---|---|---:|
| Clássico | 10 rodadas, ritmo padrão | 30 |
| Rápido | 20 rodadas, intervalos menores e mais inimigos | 40 |
| Só Rimuru | Apenas Rimuru como inimigo | 60 |
| Infinito | Não termina; a quantidade de inimigos aumenta progressivamente | 50 |
| Sobrevivência | Muitas unidades e intervalos curtos, partida longa | 35 |
| Corrida | 10 rodadas em ritmo acelerado e com mais inimigos | 45 |

O dinheiro inicial é definido pelo host antes da partida começar e sincronizado para todos.

### 3. Cenas separadas por modo

As cenas de partida foram organizadas em:

`cenas/modos/`

- `primaria_classico.tscn`
- `primaria_rapido.tscn`
- `primaria_so_rimuru.tscn`
- `primaria_infinito.tscn`
- `primaria_sobrevivencia.tscn`
- `primaria_corrida.tscn`

Todas usam a mesma base visual/mecânica da fase principal, mas ficam separadas para facilitar futuras alterações específicas de cada modo.

A seleção da cena é feita por:

`NetworkManager.cena_do_modo()`

### 4. Regras de criação de torres

Validação em `NetworkManager.posicao_torre_valida()`:
- não é permitido colocar torre sobre um tile de qualquer `TileMapLayer` que esteja no grupo global `areaComCoisa` (checado célula por célula, não depende de colisão/física no TileSet);
- a torre precisa ficar pelo menos **55 pixels do caminho**;
- a posição é validada no preview antes de abrir o painel de confirmação;
- uma posição inválida não desconta dinheiro.

### Estrutura relevante

```text
cenas/
├── modos/
│   ├── primaria_classico.tscn
│   ├── primaria_rapido.tscn
│   ├── primaria_so_rimuru.tscn
│   ├── primaria_infinito.tscn
│   ├── primaria_sobrevivencia.tscn
│   └── primaria_corrida.tscn
├── menus/
│   └── lobby.tscn
└── primaria.tscn

script/
├── NetworkManager.gd
├── primaria.gd
├── lobby.gd
├── controle_velocidade.gd
└── controleDeTudo.gd
```

## Multiplayer e autoridade

O host continua sendo a autoridade para:
- iniciar a partida;
- escolher o modo;
- alterar a velocidade;
- validar colocação de torres;
- gastar/ganhar dinheiro;
- controlar vida e fim de jogo.

O cliente recebe os estados sincronizados e não consegue trocar o modo ou a velocidade apenas alterando a interface.

## Tilemap de cada modo (atualizado)

As cenas de `cenas/modos/` eram cópias de um cenário antigo que ficou com o
tilemap bugado. Agora cada uma é uma cópia de uma das fases da campanha já
corrigidas (`cenas/niveis/`), reaproveitando o cenário/caminho dela:

| Modo | Cenário usado |
|---|---|
| Clássico | Nível 1 |
| Rápido | Nível 2 |
| Infinito | Nível 3 |
| Sobrevivência | Nível 4 |
| Corrida | Nível 5 |
| Só Rimuru | Nível 8 |

Pra trocar o cenário de um modo: duplique a fase da campanha que quiser usar
(`cenas/niveis/nivel_N.tscn`), salve como `cenas/modos/primaria_<modo>.tscn`
(sobrescrevendo), confira `inimigos_normais`/`miniboss_scene`/`boss_final_scene`
no Inspector da raiz, e não mexa em mais nada -- `NetworkManager.cena_do_modo()`
já aponta pro caminho certo sozinho.

## Observação sobre futuras alterações

As cenas dos modos estão separadas de propósito. Isso permite, por exemplo, futuramente colocar uma regra exclusiva no modo `so_rimuru` ou criar uma configuração visual própria para `infinito` sem precisar alterar todos os outros modos.
