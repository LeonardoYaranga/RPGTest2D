# Guía de Estructura Narrativa: De Campfire / Novela Ligera a Godot (Dialogic) y Ren'Py

Esta guía define el estándar de escritura para que cualquier guion, diálogo o descripción creado manualmente o con IAs pueda convertirse directamente a **Dialogic 2 (Godot)** o **Ren'Py** sin perder claridad sobre quién habla y qué es narración.

---

## 1. El Problema Común al Escribir con Chats / Campfire

Cuando se escribe estilo novela tradicional o con prompts genéricos:
- Los diálogos usan guiones (`—Hola—dijo Juan`) o comillas sueltas.
- No se especifica con claridad técnica el **identificador del personaje** (ID único en el motor).
- Las descripciones de ambiente o acciones se mezclan dentro del mismo párrafo de diálogo.
- **Resultado:** Pasar eso a Dialogic o Ren'Py requiere un reescrito manual línea por línea.

---

## 2. El Estándar Recomendado: Formato de 3 Capas

Para evitar confusiones, cada escena se divide en tres bloques bien diferenciados:

```markdown
### Escena X: [Nombre de la Escena / Momento]

[AMBIENTE / ACCIÓN / GAMEPLAY]
Descripción de lo que ocurre en pantalla o lo que hace el jugador.
(Movimiento, cinemática, interacción [F], etc.)

[GUION NARRATIVO]
Narrador: El silencio de la celda es roto por un parpadeo eléctrico.
Protagonista: ¿Dónde estoy...? Mi cabeza da vueltas.
Narrador: Al intentar ponerse de pie, algo cruje bajo su bota.
Protagonista (confundido): ¿Una fotografía...?

[EFECTO / SFX / SEÑAL]
- SFX: zumbido_luces, paso_pesado
- Señal/Evento: trigger_cinematica_foto
```

---

## 3. Reglas de Escritura para Diálogos vs Narración

### A. Diálogos de Personajes
- Siempre usar el formato: `NombreDelPersonaje: Texto del diálogo`
- Si tiene emoción/retrato: `NombreDelPersonaje (emoción): Texto del diálogo`
- **Importante:** El nombre debe coincidir con el identificador del personaje en Dialogic (`.dch`) o Ren'Py (`Character`).

### B. Narración y Descripciones (Lo que NO es hablado)
- En el guion de diseño, usar la etiqueta `Narrador:` o simplemente párrafos descriptivos en el bloque de narración.
- **En Dialogic 2:**
  - Si escribes una línea de texto **sin** prefijo de personaje, Dialogic la interpreta como texto narrativo/anónimo (sin nombre en el cuadro de diálogo):
    ```dtl
    El pasillo está completamente a oscuras.
    patient: No veo nada...
    ```
- **En Ren'Py:**
  - El texto entre comillas sin variable es narración pura:
    ```renpy
    "El pasillo está completamente a oscuras."
    patient "No veo nada..."
    ```

### C. Monólogos Interiores / Pensamientos
- Puedes usar una emoción o convención específica:
  - `Protagonista (pensando): Esto me resulta familiar...`
  - O formato itálica: `Protagonista: *Esto me resulta familiar...*`

---

## 4. Tabla de Equivalencias Rápidas

| Elemento | Formato Guion (Obsidian / Campfire) | Dialogic 2 (Godot `.dtl`) | Ren'Py (`.rpy`) |
| :--- | :--- | :--- | :--- |
| **Línea Hablada** | `Protagonista: ¿Quién anda ahí?` | `patient: ¿Quién anda ahí?` | `p "¿Quién anda ahí?"` |
| **Con Emoción** | `Protagonista (asustado): ¡Aléjate!` | `patient (scared): ¡Aléjate!` | `p scared "¡Aléjate!"` |
| **Narración / Ambiente** | `Narrador: La puerta se abre lentamente.` | `La puerta se abre lentamente.` | `"La puerta se abre lentamente."` |
| **Efecto de Audio** | `[SFX: puerta_chirrido]` | `[sound path="res://sfx/door.wav"]` | `play sound "audio/door.ogg"` |
| **Disparo de Evento** | `[SEÑAL: shatter_glitch]` | `[signal arg="shatter_glitch"]` | `$ trigger_shatter()` |
| **Elección / Opciones** | `[DECISIÓN: Opción A / Opción B]` | `- Opción A<br>    ...<br>- Opción B<br>    ...` | `menu:<br>    "Opción A":<br>        ...<br>    "Opción B":<br>        ...` |

---

## 5. Recomendación de Prompt para Campfire / IAs de Asistencia

Cuando le pidas a un chat de IA que desarrolle o refine una historia para tu juego, usa esta instrucción:

> *"Actúa como guionista de videojuegos. Escribe la historia en formato estructurado para Dialogic/Ren'Py. Sigue estas reglas estrictas:*  
> *1. Separa con claridad las líneas habladas usando siempre el formato `Personaje: Diálogo` o `Personaje (emoción): Diálogo`.*  
> *2. Cuando sea una narración, pensamiento de fondo o descripción de ambiente que no diga ningún personaje en voz alta, usa el prefijo `Narrador: Descripción` o ponlo en un bloque `[NARRACIÓN]`.*  
> *3. Incluye bloques breves `[ACCIÓN / GAMEPLAY]` para saber qué hace el jugador y `[SFX / EFECTO]` para los eventos audiovisuales."*
