# Guía Técnica de Arte: Animaciones de Combate 2.5D (Beat 'em up)

Esta guía detalla la lista de animaciones necesarias para dotar de identidad visual y peso a cada golpe del sistema de combos (*River City Girls 2* / *Mortal Kombat*).

---

## 1. Especificaciones de Dibujo (Pixel Art / Aseprite)

* **Resolución base:** 16x32 (personaje estándar), 32x32 o 48x48 píxeles si se añaden efectos de estela o extremidades extendidas.
* **Punto de anclaje (Pivote):** **Centro inferior (en los pies)**. Es crucial para que los personajes no "salten" o se desfacen del `GroundShadow` y el `CollisionShape3D` en el plano 2.5D.
* **Frames de impacto:** En juegos de pelea, el frame con el golpe completamente extendido debe ser el más legible y con silueta clara (*Key Pose* de impacto).

---

## 2. Animaciones de Ataque del Jugador

| Nombre Animación | Secuencia | Total Frames | Frame de Impacto | Duración Aprox. | Descripción y Claves de Dibujo |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `jab` | `H` | 3 frames | Frame 1 | 0.16s - 0.18s | **Golpe Recto Rápido:** Frame 0: puño cargando ligeramente hacia el mentón. Frame 1: puño estirado hacia adelante (línea recta). Frame 2: retorno a guardia. |
| `straight` | `HH` | 3 frames | Frame 1 | 0.20s - 0.22s | **Golpe Cruzado (Cross):** Frame 0: giro de torso y cadera. Frame 1: puñetazo largo y potente con hombro adelantado. Frame 2: recogida rápida. |
| `hook` | `HHH` | 4 frames | Frame 2 | 0.26s - 0.28s | **Gancho Horizontal:** Frame 0: torso girado hacia atrás cargando peso. Frame 1: arco horizontal curvado. Frame 2: impacto lateral con codo flexionado. Frame 3: inercia y retorno. |
| `heavy` | `J` | 4 frames | Frame 2 | 0.30s - 0.32s | **Overhand / Puño Descendente:** Frame 0: alzada de brazo por encima de la cabeza. Frame 1: caída veloz en diagonal hacia abajo. Frame 2: impacto contundente a la altura del pecho. Frame 3: postura agachada estabilizándose. |
| `kick` | `K` | 3 - 4 frames | Frame 1 | 0.24s - 0.26s | **Barrida Baja (Sweep):** Frame 0: agacharse flexionando pierna de apoyo. Frame 1: pierna estirada girando a ras de suelo (tobillos). Frame 2: inercia del giro. Frame 3: incorporarse a guardia. |
| `kick_finisher` | `HHK` | 4 frames | Frame 2 | 0.28s - 0.30s | **Patada Circular (Roundhouse):** Frame 0: pivote de pie de apoyo, rodilla arriba. Frame 1: extensión explosiva de la patada en el pecho con torso inclinado. Frame 2: impacto con estela de viento. Frame 3: recogida de pierna. |
| `launcher` | `HHHK` | 5 frames | Frame 2 | 0.35s - 0.38s | **Patada Ascendente (Flash Kick):** Frame 0: agache comprimiendo como resorte. Frame 1: salto vertical con pierna pateando hacia arriba 90° (hacia el cielo). Frame 2: cuerpo extendido en el aire. Frame 3: caída. Frame 4: flexión de rodillas al aterrizar. |

---

## 3. Animaciones de Reacción del Enemigo

| Nombre Animación | Tipo Reacción | Total Frames | Descripción |
| :--- | :--- | :--- | :--- |
| `hurt_light` | `HITSTUN` | 2 frames | **Impacto Ligero:** Frame 0: cabeza y hombros echados hacia atrás por el golpe. Frame 1: recuperación rápida a guardia. |
| `stagger` | `STAGGER` | 3 frames | **Tambaleo Pesado:** Frame 0: pecho sacudido, brazos abiertos perdiendo control. Frame 1: paso torpe hacia atrás perdiendo equilibrio. Frame 2: recuperación de pie. |
| `launched` | `LAUNCH` | 2 - 3 frames | **Vuelo Aéreo (Juggle):** Frame 0: cuerpo curvado arqueado hacia arriba volando. Frame 1: caída libre mirando hacia arriba con ropa ondeando. |
| `knockdown` | `KNOCKDOWN` | 2 frames | **Caída y Reposo en el Suelo:** Frame 0: impacto de espaldas contra el suelo con leve rebote elástico. Frame 1: tendido boca arriba inerte en el piso. |
| `getup` | `GETUP` | 4 frames | **Reincorporación:** Frame 0: apoyo de manos o codos en el suelo. Frame 1: rodillas dobladas bajo el cuerpo. Frame 2: impulso hacia arriba. Frame 3: posición de combate. |

---

## 4. Efectos Visuales Complementarios (VFX Opcionales)

1. **Hit Spark Ligero (3 frames):** Estrella / destello amarillo rápido en el punto de contacto de golpes directos (jab/cross).
2. **Hit Spark Pesado (4 frames):** Explosión con líneas de choque tipo cómic para golpes contundentes (gancho, roundhouse, launcher).
3. **Motion Trail (3 frames):** Estela semitransparente blanca/amarilla en arco que refuerza la trayectoria de las patadas y ganchos.
4. **Ground Dust (4 frames):** Nube de polvo horizontal a ras de suelo cuando un enemigo azota contra el piso en *knockdown* o cuando el jugador aterriza tras un *launcher*.

---

## 5. Cómo Integrar las Nuevas Animaciones en Godot

1. Dibuja los frames en tu editor preferido (Aseprite, etc.) y exporta la tira de imágenes (*spritesheet*) o frames individuales PNG.
2. Guarda los archivos en `assets/player/` o `assets/enemies/`.
3. Abre Godot y selecciona el recurso de animación correspondiente:
   * `resources/characters/default_character_frames.tres`
4. Añade cada animación (`jab`, `straight`, `hook`, `heavy`, `kick`, `kick_finisher`, `launcher`, etc.) arrastrando sus frames correspondientes y ajustando el FPS (ej. 12 - 16 FPS).
5. En los recursos de ataque (`resources/attacks/*.tres`), actualiza la propiedad `animation` para que apunte a tu nueva animación (por ejemplo `animation = &"jab"` o `animation = &"hook"`).
