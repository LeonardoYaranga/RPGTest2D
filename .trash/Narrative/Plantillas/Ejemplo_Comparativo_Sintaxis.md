# Ejemplo Comparativo: De Guion a Motores de Juego

Este ejemplo ilustra cómo traducir una misma escena con **narración de ambiente**, **diálogos con emociones**, y **eventos interactivos** entre los tres formatos.

---

## 1. En Guion de Diseño (Markdown / Obsidian / Campfire)

```markdown
### Escena: Despertar en la Celda

[AMBIENTE / ACCIÓN]
La iluminación fluorescente parpadea. El jugador yace en el suelo de concreto frío.

[GUION NARRATIVO]
Narrador: Un zumbido eléctrico rompe la quietud del pasillo.
patient (confundido): ¿Dónde... estoy?
Narrador: Al mover la mano, siente un papel doblado bajo sus dedos.
patient: ¿Una fotografía? Pero... no reconozco esta cara.

[EFECTOS / SFX]
- SFX: zumbido_luz.wav
- Señal: shatter_glitch
```

---

## 2. En Godot con Dialogic 2 (`res://dialogues/despertar.dtl`)

```dtl
# Archivo: despertar.dtl
# 1. Narración (sin nombre de personaje al inicio de línea):
Un zumbido eléctrico rompe la quietud del pasillo.

# 2. Diálogo con retrato/emoción:
patient (confundido): ¿Dónde... estoy?

# 3. Narración descriptiva intermedia:
Al mover la mano, siente un papel doblado bajo sus dedos.

# 4. Disparo de evento a Godot:
[signal arg="shatter_glitch"]

# 5. Diálogo normal:
patient: ¿Una fotografía? Pero... no reconozco esta cara.
```

> **Nota sobre Dialogic 2:**  
> Cuando una línea no tiene ningún identificador seguido de dos puntos (e.g., `Texto libre...`), Dialogic automáticamente la muestra como texto descriptivo o de narrador sin requerir un personaje ficticio.

---

## 3. En Ren'Py (`script.rpy`)

```renpy
# Definición previa de personajes
define patient = Character("Paciente", color="#4db6ac")

label escena_despertar:
    # 1. Narración descriptiva (texto suelto entre comillas):
    "Un zumbido eléctrico rompe la quietud del pasillo."

    # 2. Diálogo del personaje con emoción/expresión:
    patient confused "¿Dónde... estoy?"

    # 3. Narración intermedia:
    "Al mover la mano, siente un papel doblado bajo sus dedos."

    # 4. Disparo de evento / llamada:
    $ trigger_shatter("glitch")

    # 5. Diálogo normal:
    patient "¿Una fotografía? Pero... no reconozco esta cara."
```
