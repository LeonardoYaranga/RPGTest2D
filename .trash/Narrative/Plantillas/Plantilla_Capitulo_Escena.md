# [Nombre del Capítulo o Bucle / Escenario]

> **ID de Línea de Tiempo / Carpeta:** `res://dialogues/capitulo_X/`  
> **Estado del Personaje:** (e.g., Nivel de memoria, equipamiento, estado emocional)  
> **Objetivo de la Escena:** (Qué debe descubrir o lograr el jugador aquí)  
> **Ubicaciones:** (De dónde a dónde se mueve)  

---

## Escena 1: [Título de la Escena]

### [AMBIENTE / ACCIÓN / GAMEPLAY]
* **Estado inicial:** Describir la posición inicial del jugador, iluminación y cámara.
* **Mecánica:** Qué controles o interacción están disponibles (e.g., caminar con WASD, pulsar [F] para interactuar con la consola).

### [GUION NARRATIVO]
*Archivo Dialogic sugerido: `res://dialogues/capitulo_X/escena_1.dtl`*

Narrador: Una breve descripción de lo que se percibe en la atmósfera antes de que hable alguien.  
Personaje_A: Primera línea de diálogo.  
Personaje_B (sorprendido): Respuesta con indicación de emoción o tono.  
Narrador: El sonido de unos pasos rompe la conversación.  
Personaje_A (susurrando): ¡Silencio! Alguien viene.

### [EFECTOS / SEÑALES / SFX]
* **SFX:** `pasos_metalicos.wav`, `alarma_baja.ogg`
* **Señal a Godot:** `[signal arg="activar_patrulla"]`
* **Transición visual:** Fundido o distorsión si aplica.

---

## Escena 2: [Título de la Escena]

### [AMBIENTE / ACCIÓN / GAMEPLAY]
* Acción del jugador:

### [GUION NARRATIVO]
*Archivo Dialogic sugerido: `res://dialogues/capitulo_X/escena_2.dtl`*

Narrador: ...  
Personaje_A: ...  

### [EFECTOS / SEÑALES / SFX]
* ...
