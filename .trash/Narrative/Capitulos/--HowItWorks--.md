# Capítulos y Guiones — How It Works

Esta carpeta contiene el desglose narrativo de **I Am...?** estructurado por los tres bucles temporales y cognitivos del juego.

---

## Formato del Sistema Narrativo (3 Capas)

Para cada escena de los bucles se utiliza la convención de 3 capas sincronizadas con los nodos de Godot:

1. **`[GAMEPLAY | Acción interactiva, Sigilo y Minijuegos]`**:
   Acciones que ejecuta el jugador en el motor (desplazamiento con WASD, administración de estamina, interacción `[F]`, cableado en `HackMinigame` o ejecuciones por la espalda).
2. **`[DIALOGIC | Líneas de Diálogo y Textbox]`**:
   Líneas habladas o monólogos interiores emitidos mediante timelines de Dialogic 2 (`res://dialogues/`), indicando hablante (`patient:`) y pausas.
3. **`[EFECTO / SHATTER / SFX]`**:
   Disparadores de eventos audiovisuales (`SignalHub.shatter_requested`, ruidos de cerraduras, música de fondo o animaciones de cámara).

---

## Estructura de Documentos de Bucles

- **`Bucle_01_El_Despertar_y_el_Hacking.md`**:  
  La primera toma de conciencia en la celda (`#1##`), el hallazgo de la fotografía, la escritura en la pared, el minijuego de cables, la incursión en el pasillo y el recuerdo del capitán militar en el ordenador central de la oficina.
- **`Bucle_02_Seguridad_y_el_Ataque.md`**:  
  El segundo despertar (`#174`), la asimilación del instinto letal, la infiltración del Centro de Seguridad (`SecurityHub`), la eliminación silenciosa de patrullas y la consecución del Fragmento de Camuflaje.
- **`Bucle_03_Camuflaje_y_Escape.md`**:  
  El tercer despertar (`6174`), la evasión definitiva de las patrullas armadas, la apertura de la esclusa exterior, el colapso final frente al recorte del periódico y el corte a créditos.
