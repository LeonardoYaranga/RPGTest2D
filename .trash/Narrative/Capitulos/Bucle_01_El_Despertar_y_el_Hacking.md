# Bucle 01: El Despertar y el Hacking (1ra Vez)

> **Identificador de Diálogos:** `res://dialogues/1th_time/`  
> **Estado de Identidad:** Código borroso `#1##`  
> **Fragmento Obtenido:** `Fragmento de Hackeo` (`hack`)  
> **Ubicaciones:** Celda de Asilamiento (`Jail`) → Pasillo Principal (`Hallway`) → Oficina de Archivos (`Office`)

---

## Escena 1: La Celda de Aislamiento

`[NARRADOR / AMBIENTE]`  
Un zumbido de luz fluorescente parpadea sobre un piso de concreto manchado. El silencio es denso, roto únicamente por una respiración agitada.

`[GAMEPLAY]`  
El jugador toma el control tras la transición de apertura. La velocidad está restringida mientras el protagonista se recupera del aturdimiento inicial.

`[DIALOGIC: awakening.dtl]`  
**Paciente N° #1##:** ¿Qué pasó? ¿Dónde estoy?

---

## Escena 2: La Fotografía de la Mujer

`[GAMEPLAY]`  
El jugador explora la celda con `WASD`. Cerca del colchón en el suelo hay un objeto interactivo: una fotografía desgastada. Al presionar `F`, se abre la vista de inspección (`ClueUi`).

`[DIALOGIC: memorie_photo.dtl]`  
**Paciente N° #1##:** No sé quién eres... Pero esos ojos son los mismos que veo cuando cierro los míos. Tengo que encontrarte.

---

## Escena 3: La Inscripción en la Pared y la Primera Fractura

`[GAMEPLAY]`  
El jugador se aproxima a la pared este de la celda, donde hay símbolos y diagramas de circuitos raspados en el revoque. Presiona `F` para inspeccionar.

`[DIALOGIC: wall_writing.dtl]`  
**Paciente N° #1##:** Esto ya lo había visto...  
**Paciente N° #1##:** ¡Ahhh!

`[EFECTO / SHATTER]`  
- Disparo de señal: `[signal arg="shatter_left_up"]`.  
- La pantalla se quiebra con un destello blanco y distorsión de audio.  
- Se otorga en segundo plano: `FragmentManager.grant(FragmentManager.HACK)`.

`[DIALOGIC: Continuación]`  
**Paciente N° #1##:** Espera... ¿Soy un hacker?  
**Paciente N° #1##:** Tal vez por eso me encerraron.

---

## Escena 4: La Puerta de la Celda y el Minijuego

`[GAMEPLAY]`  
El jugador interactúa con el teclado numérico de la puerta metálica. Con el fragmento de hackeo recién asimilado, se despliega el tablero de cableado (`HackMinigame`). El jugador une los cuatro cables por código de color.

`[EFECTO / SFX]`  
- `SolveSfx` resuena al conectar el último cable.  
- Sonido de manija y pestillo cediendo (`GameManager.play_door_handle()`).

`[DIALOGIC: door_hacked.dtl]`  
**Paciente N° #1##:** Tengo que salir y descubrir qué me está pasando.

---

## Escena 5: El Pasillo Principal y los Pasos en las Sombras

`[GAMEPLAY]`  
Fundido a negro (`Fader`). Transición a `res://scenes/room/hallway/hallway.tscn`. Al salir, suena la puerta cerrándose a sus espaldas.

`[DIALOGIC: intro_hallway.dtl]`  
**Paciente N° #1##:** Hay guardias vigilando este pasillo... No puedo dejar que me vean.

`[GAMEPLAY]`  
- El jugador debe evitar los conos de visión amarillos de los custodios patrulleros.  
- Al no tener aún capacidad ofensiva, debe esperar a que los guardias se alejen para esprintar (`Espacio`) hacia la puerta de la Oficina de Archivos al fondo del corredor.

---

## Escena 6: La Oficina y el Recuerdo del Capitán

`[GAMEPLAY]`  
El paciente ingresa en la oficina administrativa. Sobre el escritorio hay una computadora con la pantalla encendida. Presiona `F` para examinar el monitor.

`[DIALOGIC: computer_memory.dtl]`  
**Paciente N° #1##:** Con que esto era antes... un capitán de las fuerzas armadas. Creo que ya voy entendiendo quién soy.  
**Paciente N° #1##:** Espera... ¿y esto?

`[EFECTO / SHATTER]`  
- Disparo de señal: `[signal arg="shatter_right_down"]`.  
- Fractura diagonal de la pantalla.  
- Sonido gutural de taquicardia y quiebre psíquico.  
- Desbloqueo: `FragmentManager.grant(FragmentManager.ATTACK)`.

`[DIALOGIC: Continuación]`  
**Paciente N° #1##:** Muerte... Mujer... ##74...  
**Paciente N° #1##:** ¿Qué significa todo esto...?  
**Paciente N° #1##:** Estando atrás de los guardias puedo acabar con ellos.

`[EFECTO / FADE]`  
La sobrecarga sensorial nubla la vista del protagonista. La pantalla se funde bruscamente a negro. Un sonido sordo de caída marca el final del primer ciclo.
