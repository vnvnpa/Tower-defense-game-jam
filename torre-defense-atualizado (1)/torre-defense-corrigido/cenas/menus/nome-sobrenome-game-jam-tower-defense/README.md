# Tower Defense DOT - Game Jam 2D (Colegio Joao Netto de Campos)

Jogo Tower Defense 2D feito em **Godot 4.2+** (GDScript). Abra a pasta no Godot e aperte F5.
Objetivo: sobreviver a 10 ondas sem deixar a Base ficar sem vidas (20 vidas).

## Controles
| Acao | Controle |
|---|---|
| Escolher torre | Botoes no topo ou teclas 1, 2, 3, 4 |
| Construir torre | Clique esquerdo (nao pode ser no caminho nem colada em outra torre) |
| Vender torre (60%) | Clique direito sobre a torre |
| Iniciar onda | Espaco ou botao "Iniciar Onda" |
| Reiniciar | R |

## Torres (todas com efeitos DOT / debuff)
| Torre | Custo | Efeito |
|---|---|---|
| Sangramento (1) | $50 | Bleed: 8 de dano/s por 4s |
| Fogo (2) | $80 | Burn: 12 de dano/s por 3s; o fogo se espalha para inimigos proximos |
| Gelo (3) | $60 | Freeze: reduz a velocidade em 60% por 2s |
| Veneno (4) | $70 | Poison: 6 de dano/s por 5s e +30% de dano recebido |

## Inimigos
Normal, Rapido (menos vida, mais veloz) e Tanque (mais vida, armadura, tira 3 vidas da base).

## Estrutura do codigo
- `main.gd`: caminho (Path2D), ondas (Timer), construcao, HUD, vitoria/derrota.
- `tower.gd`: alcance com Area2D, disparo com Timer, dados das 4 torres.
- `projectile.gd`: projetil teleguiado que aplica dano + efeito.
- `enemy.gd`: PathFollow2D, barra de vida, Timer de DOT, sinais `died` e `reached_base`.
