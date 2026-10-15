# Bucle 03: Camuflaje y Escape (3ra Vez y Clímax)

> **Identificador de Diálogos:** `res://dialogues/3th_time/`  
> **Estado de Identidad:** Código completo `6174` (Constante del bucle)  
> **Fragmento Activo:** `Fragmento de Camuflaje` (`camouflage`)  
> **Ubicaciones:** Celda de Aislamiento (`Jail`) → Pasillos de Máxima Seguridad → Puerta de Escape Exterior (`EndingDoor`)

---

## Escena 1: La Furia del Bucle Infinito

`[NARRADOR / AMBIENTE]`  
La misma celda. La misma bombilla titilante. Pero el protagonista ya no despierta desorientado: se levanta con los puños crispados y la respiración entrecortada por la rabia.

`[DIALOGIC: awakening_3.dtl]`  
**Paciente 6174:** ¡Maldita sea! ¿Otra vez aquí? ¿Esto es una especie de bucle sin fin?

`[GAMEPLAY]`  
El paciente no pierde ni un segundo. Posee todos los fragmentos del catálogo (`hack`, `attack`, `camouflage`). Cruza la celda con determinación; la cerradura se abre al instante bajo sus manos expertas.

---

## Escena 2: La Infiltración Definitiva

`[GAMEPLAY]`  
- El pasillo y las zonas adyacentes están en alerta máxima. Guardias armados con pistolas custodian los accesos críticos.  
- Con el **Fragmento de Camuflaje**, el jugador puede esquivar los conos de luz más estrechos, sincronizando carreras cortas con sprint (`Espacio`) y deslizándose pegado a los muros.  
- Los guardias que bloquean el camino son neutralizados quirúrgicamente por la espalda. No hay margen para el error: un disparo certero de un custodio acabaría con su vida.

---

## Escena 3: La Puerta de Salida (`EndingDoor`)

`[GAMEPLAY]`  
Al final del corredor de seguridad se alza una pesada puerta de acero reforzado que da al exterior (`res://scenes/doors/ending_door/ending_door.tscn`).  
El jugador se aproxima y pulsa `F` para interactuar.

`[EFECTO / SFX]`  
- Sonido mecánico de la manija desbloqueándose: `GameManager.play_door_handle()`.  
- La puerta cede lentamente hacia la luz exterior.  
- Se emite la señal del clímax: `SignalHub.emit_on_ending_requested()`.

---

## Escena 4: La Revelación del Periódico y el Desenlace (`EndingScreen`)

`[CINEMÁTICA / ANIMATIONPLAYER: ending]`  
1. **Fundido a Negro Absoluto:** La pantalla se sumerge en la oscuridad (`Backdrop:color = Color(0, 0, 0, 1)`).
2. **El Recorte Giratorio:** Desde el fondo de la pantalla surge rotando a gran velocidad la primera plana de un periódico antiguo (`NewspaperGirl`).
3. **El Titular y la Fotografía:** El periódico se detiene en primer plano. La imagen es la misma fotografía de la mujer que el paciente guardaba en su celda. El titular expone los detalles de una tragedia dolorosa, revelando que el internamiento en el asilo y la amnesia del protagonista son el resultado del trauma inasimilable de su pérdida.
4. **El Grito de Frustración:** Sobre el silencio espectral, resuena el alarido desgarrador del protagonista (`res://assets/SFX/newSFX/frustrated_1/frustrated_1.wav`), dándose cuenta de que escapar del edificio físico no lo libera de la cárcel de su propia mente.
5. **Música y Continuación:** Entra el tema melancólico de violines (`MenuTheme.ogg`). Sobre la pantalla se desvanece el periódico y emerge en tipografía blanca con contorno negro:
   > *"To be continued..."*
6. **Créditos Finales:**
   ```
   DEVELOPERS
   Wyes_Lje
   AXELDOGE

   GAME DESIGN
   DELIOS

   ART
   JACSMITH

   MUSIC
   ANDY
   ```
7. **Cierre de Ciclo:** En la parte inferior se ilumina la instrucción `[F] Volver al menú`. Al pulsarla, se limpian los fragmentos de la memoria y el juego retorna a la pantalla de título, listo para ser rejugado o continuado en futuras expansiones.
