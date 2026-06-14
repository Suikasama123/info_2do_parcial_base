# Match-3 — Infografía, I/2026

Juego **Match-3** desarrollado en **Godot 4.6** como proyecto para el segundo parcial de la materia Infografía. El proyecto implementa un juego de intercambio de piezas completo con sistema de puntaje, niveles, piezas especiales, detección de tablero bloqueado, persistencia de progreso y efectos de sonido.

---

## Cómo ejecutar

1. Instala [Godot 4.6](https://godotengine.org/download).
2. Abre esta carpeta desde el editor de Godot (botón *Import* → selecciona `project.godot`).
3. Presiona `F5` (o el botón *Play* ▶). La escena principal es `scenes/game.tscn`.

---

## Jugabilidad

El juego se desarrolla en una grilla de 8 × 10 con piezas de 6 colores distintos. El jugador desliza el dedo (o el mouse) sobre piezas adyacentes para intercambiarlas. Si el intercambio produce una combinación de 3 o más piezas del mismo color en línea recta (horizontal o vertical), estas se destruyen, las piezas superiores caen por gravedad y se generan piezas nuevas desde arriba. Las combinaciones en cascada incrementan un multiplicador de puntaje.

Cada intercambio exitoso consume un movimiento del contador. Si el contador llega a 0 sin haber cumplido el objetivo del nivel, la partida termina en derrota. Si se cumple el objetivo antes de agotar los movimientos, se avanza al siguiente nivel.

Si el tablero se queda sin jugadas posibles, el sistema lo detecta automáticamente y rebaraja las piezas hasta encontrar una configuración con al menos una jugada válida.

---

## Niveles

El juego incluye 3 niveles con objetivos diferenciados, definidos en archivos JSON externos:

| Nivel | Archivo | Objetivo | Meta | Movimientos |
|-------|---------|----------|------|-------------|
| 1 | `levels/level_0.json` | Alcanzar puntaje | 1000 pts | 20 |
| 2 | `levels/level_1.json` | Recolectar piezas azules | 15 azules | 25 |
| 3 | `levels/level_2.json` | Alcanzar puntaje | 2500 pts | 30 |

Al completar el nivel 3, el ciclo vuelve a comenzar desde el nivel 1. El progreso (nivel alcanzado y mejor puntaje) se guarda automáticamente al finalizar cada partida y se restaura al abrir el juego.

---

## Sistemas implementados

| # | Sistema | Descripción |
|---|---------|-------------|
| B1 | Puntaje + HUD | Cada combinación suma puntaje (50 pts × piezas destruidas × multiplicador de combo). Las etiquetas del HUD se actualizan en tiempo real mediante señales. |
| B2 | Límite de movimientos | El contador disminuye con cada jugada válida. Al llegar a 0 sin cumplir el objetivo, la partida termina. |
| B3 | Victoria / Derrota + Reinicio | Pantalla superpuesta con resultado, puntaje obtenido, botón de reinicio y botón de siguiente nivel (solo en victoria). |
| B4 | Efectos de sonido | Sonidos para intercambio, combinación, jugada inválida, pieza especial, victoria y derrota, reproducidos desde archivos Ogg Vorbis. |
| M1 | Sistema de niveles | 3 niveles con metas distintas (puntaje y recolección). La configuración vive en archivos JSON, no en código. El HUD muestra la meta y el progreso actual. |
| M2 | Bloqueo + rebarajado | Detección exhaustiva de jugadas posibles probando todos los intercambios del tablero. Si no hay ninguna, rebaraja hasta encontrar una configuración válida. |
| M3 | Piezas especiales | 4 en línea → pieza de fila o columna (limpia toda la línea). 5 en línea → rainbow (elimina todas las piezas del color objetivo). Al intercambiar dos especiales entre sí, ambos efectos se activan simultáneamente. |
| M4 | Persistencia | Guarda y carga el nivel alcanzado y el mejor puntaje desde `user://save_game.json`. Los niveles se cargan desde archivos externos `levels/level_N.json`. |

---

## Estructura del proyecto

```
match3/
├── .gitignore
├── project.godot                  # Configuración del motor
├── icon.svg                       # Ícono del proyecto
├── README.md                      # Esta documentación
├── enunciado.md                   # Enunciado del parcial con rúbrica
│
├── assets/                        # Recursos del juego
│   ├── background.png             # Fondo de la escena
│   ├── bottom_ui.png              # Barra decorativa inferior
│   ├── top_ui.png                 # Barra decorativa superior (HUD)
│   ├── fonts/
│   │   └── Kenney Blocks.ttf      # Fuente tipográfica del HUD
│   ├── pieces/                    # Sprites de piezas (6 colores × 4 tipos)
│   │   ├── Blue Piece.png         #   Pieza normal (Blue, Green, Light Green,
│   │   ├── Blue Row.png           #   Orange, Pink, Yellow)
│   │   ├── Blue Column.png        #   Especial: limpia fila
│   │   ├── Blue Adjacent.png      #   Especial: área adyacente (no implementada)
│   │   ├── ...                    #   (mismo esquema para los 6 colores)
│   │   └── Rainbow.png            #   Especial: elimina todas las de un color
│   └── sounds/
│       └── Match 3 Sounds/
│           ├── Sounds/
│           │   ├── 1.ogg          #   Intercambio
│           │   ├── 3.ogg          #   Combinación
│           │   ├── 4.ogg          #   Jugada inválida
│           │   ├── 5.ogg          #   Pieza especial
│           │   ├── 6.ogg          #   Derrota
│           │   └── 7.ogg          #   Victoria
│           └── Music/             #   Pistas musicales de fondo
│
├── scripts/                       # Código fuente GDScript
│   ├── grid.gd                    #   Controlador principal del juego
│   ├── piece.gd                   #   Comportamiento de cada pieza
│   ├── top_ui.gd                  #   Lógica del HUD
│   └── level_config.gd            #   Configuración de niveles (class_name global)
│
├── scenes/                        # Escenas Godot
│   ├── game.tscn                  #   Escena principal del juego
│   ├── piece.tscn                 #   Plantilla base de pieza (Node2D + Sprite2D)
│   ├── blue_piece.tscn            #   Pieza azul (hereda de piece.tscn)
│   ├── green_piece.tscn           #   Pieza verde
│   ├── light_green_piece.tscn     #   Pieza verde claro
│   ├── orange_piece.tscn          #   Pieza naranja
│   ├── pink_piece.tscn            #   Pieza rosa
│   ├── yellow_piece.tscn          #   Pieza amarilla
│   └── top_ui.tscn                #   Interfaz superior (HUD)
│
└── levels/                        # Datos de niveles
    ├── level_0.json               #   Nivel 1: alcanzar 1000 pts en 20 mov.
    ├── level_1.json               #   Nivel 2: recolectar 15 azules en 25 mov.
    └── level_2.json               #   Nivel 3: alcanzar 2500 pts en 30 mov.
```

> **Nota:** Las carpetas `.godot/` y los archivos `*.import` y `*.uid` son generados automáticamente por el motor y están excluidos del repositorio mediante `.gitignore`.

---

## Descripción de archivos principales

### `scripts/grid.gd`
Controlador central del juego (740 líneas). Gestiona:
- Grilla bidimensional de 8 × 10
- Spawneo de piezas sin combinaciones iniciales
- Intercambio animado entre piezas adyacentes
- Detección de combinaciones de 3, 4 y 5 piezas en línea
- Destrucción, colapso por gravedad y relleno con nuevas piezas
- Ciclo de cascada con temporizadores
- Puntaje con multiplicador de combo
- Contador de movimientos
- Efectos de sonido
- Objetivos de nivel y condiciones de victoria/derrota
- Detección de tablero bloqueado y rebarajado
- Activación de piezas especiales (fila, columna, rainbow)
- Pantalla de game over con reinicio y avance de nivel
- Persistencia de progreso

### `scripts/piece.gd`
Define una pieza individual (42 líneas):
- Propiedad `color` (String)
- Propiedad `special_type` ("row", "column", "rainbow" o "")
- Método `move(target)` — anima la pieza a una posición con transición elástica
- Método `dim()` — atenúa visualmente la pieza al ser marcada para destrucción
- Método `set_special(type)` — cambia la textura del sprite al tipo especial correspondiente
- Método `clear_special()` — restaura la textura original de la pieza

### `scripts/top_ui.gd`
Lógica del HUD (46 líneas):
- Recibe señales de `grid.gd` para actualizar puntaje, contador y progreso del objetivo
- Muestra la meta del nivel actual (puntaje a alcanzar o color a recolectar)

### `scripts/level_config.gd`
Recurso global declarado con `class_name LevelConfig` (40 líneas):
- Enum `Objetivo { PUNTAJE, RECOLECTAR_COLOR }`
- Método estático `get_level(index)` — carga y parsea un nivel desde `levels/level_N.json`
- Método estático `get_level_count()` — cuenta cuántos archivos de nivel existen

### `scenes/game.tscn`
Escena principal. Contiene:
- `background` — imagen de fondo
- `top_ui` — instancia de `top_ui.tscn` con el HUD
- `bottom_ui` — barra decorativa inferior
- `grid` — nodo Node2D con script `grid.gd`, que contiene 3 timers:
  - `destroy_timer` (0.5s) — pausa antes de destruir piezas
  - `collapse_timer` (0.5s) — pausa antes de colapsar columnas
  - `refill_timer` (0.5s) — pausa antes de rellenar

### `scenes/top_ui.tscn`
Interfaz superior con etiquetas de puntaje, contador de movimientos y objetivo del nivel.

### `scenes/piece.tscn` y `scenes/*_piece.tscn`
La plantilla base `piece.tscn` define un nodo `Node2D` con un hijo `Sprite2D` y el script `piece.gd`. Cada pieza de color hereda de ella (`instance()`), estableciendo la propiedad `color` y la textura del sprite correspondiente.

---

## Flujo de ejecución

```
Inicio
  │
  ├─ Grid._ready()
  │   ├─ _init_sounds()       → Carga los 6 sonidos como AudioStreamPlayer
  │   ├─ _load_progress()     → Restaura nivel y mejor puntaje desde disco
  │   ├─ _load_level()        → Carga configuración del nivel desde JSON
  │   ├─ spawn_pieces()       → Genera grilla sin matches iniciales
  │   └─ _connect_ui()        → Conecta señales con top_ui
  │
  └─ _process() [bucle]
       │
       ├─ touch_input()       → Captura deslizamiento del jugador
       │    └─ swap_pieces()  → Intercambia piezas animadamente
       │         │
       │         ├─ ¿Hay especiales? → _activate_specials()
       │         └─ No → find_matches()
       │
       ├─ find_matches()      → Detecta líneas de 3+, 4 y 5+
       │    ├─ Marca piezas como matched
       │    ├─ Programa especiales pendientes
       │    └─ Inicia destroy_timer
       │
       ├─ destroy_matched()   → Elimina piezas, suma puntaje, reproduce sonido
       │    └─ Inicia collapse_timer
       │
       ├─ collapse_columns()  → Desplaza piezas hacia abajo
       │    └─ Inicia refill_timer
       │
       ├─ refill_columns()    → Genera piezas nuevas desde arriba
       │    └─ check_after_refill()
       │         │
       │         ├─ ¿Hay cascada? → combo_count++ → find_matches()
       │         └─ No → _check_level_objective()
       │                    → _check_board_lock()
       │                    → state = MOVE (espera input)
       │
       ├─ _check_level_objective()
       │    ├─ ¿Objetivo cumplido? → _on_level_won() → overlay victoria
       │    └─ ¿Movimientos agotados? → _on_level_lost() → overlay derrota
       │
       └─ _check_board_lock()
            ├─ ¿Hay jugadas válidas? → no hace nada
            └─ No → _rebarajar() → shuffle hasta encontrar jugada
```

---

## Tecnologías utilizadas

- **Motor:** Godot 4.6 (Forward Plus)
- **Lenguaje:** GDScript
- **Formato de datos:** JSON para niveles y persistencia
- **Audio:** Ogg Vorbis
- **Sprites:** PNG
- **Tipografía:** Kenney Blocks (Kenney Fonts)
- **Resolución:** 576 × 1024 px (modo retrato), escalado `canvas_items` con `keep_width`

---

## Consideraciones técnicas

- **Ciclo de juego asíncrono:** El bucle destruir→colapsar→rellenar está sincronizado mediante 3 timers independientes (0.5s cada uno), no por fotogramas, permitiendo que las animaciones se completen antes de la siguiente fase.
- **Multiplicador de combo:** Cada cascada consecutiva suma +0.5 al multiplicador de puntaje (1.0, 1.5, 2.0...), incentivando cadenas largas.
- **Creación de especiales:** Las piezas especiales se colocan en la posición central de la línea que las genera (índice +1 para líneas de 4, +2 para líneas de 5 o más). Si esa posición ya tiene un especial pendiente, se intenta una mejora a rainbow.
- **Rebarajado:** El algoritmo prueba hasta 100 shuffles aleatorios. Si ninguno produce jugadas válidas (caso extremadamente raro), retorna sin cambios.
- **Persistencia:** Usa `FileAccess` de Godot para leer y escribir JSON en `user://save_game.json`. No hay dependencias externas ni plugins.
- **Comunicación:** El HUD se actualiza mediante señales de Godot (`signal` / `connect`), desacoplando el controlador del juego de la presentación.
- **No hay autoloads ni plugins** configurados en el proyecto. Toda la funcionalidad reside en scripts attachados a escenas o declarados como `class_name`.
