# Bucle 02: Seguridad y el Ataque (2da Vez)

> **Identificador de Diálogos:** `res://dialogues/2th_time/`  
> **Estado de Identidad:** Código parcial `#174`  
> **Fragmento Activo:** `Fragmento de Ataque` (`attack`)  
> **Ubicaciones:** Celda de Aislamiento (`Jail`) → Pasillo Reforzado → Centro de Seguridad (`SecurityHub`)

---

## Escena 1: El Segundo Despertar

`[NARRADOR / AMBIENTE]`  
Un jadeo violento. El protagonista abre los ojos de golpe, incorporándose del frío piso de concreto.

`[GAMEPLAY]`  
El paciente se pone en pie en la celda. Las marcas en la pared y la fotografía siguen ahí, pero su percepción es distinta; los fragmentos asimilados previamente permanecen activos en su memoria.

`[DIALOGIC: awakening_2.dtl]`  
**Paciente N° #174:** ¿Qué...? ¿De vuelta en la celda? Juraría que ya había escapado de aquí...

---

## Escena 2: Reafirmación y Salida Rápida

`[GAMEPLAY]`  
- Al inspeccionar la puerta de la celda, el conocimiento de hackeo permite abrirla sin dilación.  
- El paciente sale al pasillo sabiendo que ya no está indefenso. Su velocidad y estamina responden con mayor agilidad.

---

## Escena 3: El Centro de Seguridad (Security Hub)

`[GAMEPLAY]`  
Transición de escena hacia `res://scenes/room/security_hub/security_hub.tscn`.  
El Centro de Seguridad es un área amplia vigilada por múltiples custodios que patrullan pasillos con recovecos y pilares metálicos.

`[DIALOGIC: intro.dtl]`  
**Paciente N° #174:** Este lugar cada vez parece más aterrador...  
**Paciente N° #174:** Escucho demasiados pasos.  
**Paciente N° #174:** Pero ahora puedo silenciarlos a todos por la espalda.

---

## Escena 4: La Cacería Silenciosa

`[GAMEPLAY]`  
- **Mecánica de Asesinato:** El jugador se oculta detrás de las columnas esperando que los guardias giren en sus rutas de patrulla.  
- Al aproximarse a la espalda de un guardia sin entrar en su cono visual, el prompt de ejecución se enciende.  
- Con un clic izquierdo o la tecla `E`, el protagonista arremete: suena el corte seco (`attack_sound`) y el guardia cae fulminado al suelo.  
- Se eliminan tanto guardias de porra como tiradores armados con pistolas, evitando que abran fuego en el recinto.

---

## Escena 5: La Consola Maestra y el Fragmento de Camuflaje

`[GAMEPLAY]`  
En el centro del hub, el jugador interactúa con la consola maestra de seguridad. Se requiere calibrar los circuitos mediante el minijuego de precisión (`PrecisionMinigame`), deteniendo la aguja en la franja verde.

`[EFECTO / DESBLOQUEO]`  
- Al superar la calibración, se otorga el tercer componente: `FragmentManager.grant(FragmentManager.CAMOUFLAGE)`.  
- El paciente absorbe el patrón de distorsión luminosa, sintiendo que su cuerpo y presencia se desvanecen en la penumbra.

`[DIALOGIC: exit_locked.dtl / exit_opened.dtl]`  
**Paciente N° #174:** El sistema de esclusas perimetrales ha respondido... La salida hacia el patio exterior está abierta.

`[EFECTO / FADE]`  
Al dar un paso hacia el portón, una sirena de alarma lejana estalla en sus tímpanos. La luz roja de emergencia parpadea violentamente y un nuevo colapso psicótico lo precipita al vacío mental.
