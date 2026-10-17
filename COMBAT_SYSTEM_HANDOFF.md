# Combat / Combo System — Handoff Document

> **Project:** `Gj+2026Test` (Godot 4.7.2)
> **Scope of this doc:** the H/J/K melee combo system that was added, what changed file-by-file, how the input buffer works, how to read the console debug prints, and reference material on how combos work in action games.
> **Audience:** the project author **and any other agent** that needs to continue this mechanic.
> **Last updated:** 2026-10-15

---

## 0. Resumen rápido (ES)

- Se añadió un sistema de combos con **3 botones**: `H` (light), `J` (medium), `K` (heavy).
- Combos definidos: `H`, `H,H`, `H,H,H`, `H,H,K`, `H,H,H,K`, y sueltos `J`, `K`.
- Hay **dos buffers**:
  - `_buffer` = la secuencia **confirmada** (p. ej. `"HH"`).
  - `_pending` = la tecla pulsada **mientras** ya se está atacando (se guarda para encadenarla cuando la animación llegue a `cancel_time`).
- **Rápido = combo**, **lento = ataque básico** (el `_buffer` se borra cuando pasa la `combo_window`).
- Se añadieron **prints** en consola: `[COMBO] ...` y `[ENEMY] ...`. Se pueden apagar con el check `Debug Log` en el Inspector.
- Falta: reacciones del enemigo (lanzar / caer / levantarse) y la IA de peleador.
- El detalle largo está en las siguientes secciones (en inglés, igual que el resto de los planes del repo).

---

## 1. Estado actual

### ✅ Hecho (Fases 0–2 del plan)
- 3 acciones de input (`attack_light/medium/heavy` = `H/J/K`).
- 7 recursos de ataque (`AttackDefinition` `.tres`).
- Motor de combos (`AttackController`): buffer + tabla + combo window + cancel + lunge.
- Hitbox de ataque del jugador (creada en código).
- Hurtbox del enemigo + barra de vida.
- Enemigo "training dummy" reactivo (recibe daño, hace flash, retrocede).
- Logs de consola para seguir el combo.

### ❌ Pendiente
- **Fase 3** — reacción completa: `LAUNCHED` (vuela) → `KNOCKDOWN` (cae) → `GETUP` (se levanta). Hoy los finishers solo empujan horizontalmente (el `launch` se usa como empuje extra, no como salto real).
- **Fase 5** — IA de peleador (persigue y ataca). Hoy el enemigo es solo un muñeco.
- **Animaciones propias** de gancho/patada/finisher (hoy todos reusan `attack` con distinto `speed_scale`; decisión **D1a** del plan).

---

## 2. Mapa de archivos

Todos los caminos son relativos a `Gj+2026Test/`.

### Archivos NUEVOS

| Archivo | Qué es |
|---|---|
| `resources/attacks/attack_definition.gd` | Clase `AttackDefinition` (Resource). Define un movimiento. |
| `resources/attacks/jab.tres` | `H` — jab (4 daño). |
| `resources/attacks/straight.tres` | `H,H` — straight (5). |
| `resources/attacks/hook.tres` | `H,H,H` — hook (6). |
| `resources/attacks/kick_finisher.tres` | `H,H,K` — finisher (9). |
| `resources/attacks/kick_finisher_big.tres` | `H,H,H,K` — big finisher (14). |
| `resources/attacks/heavy.tres` | `J` — heavy (10). |
| `resources/attacks/kick.tres` | `K` — kick (8). |
| `scenes/player/attack_controller.gd` | Cerebro del combo (buffer, tabla, ventana, hitbox). |
| `scenes/enemies/enemy.gd` | Enemigo: vida, receive hit, flash, knockback, dummy/fighter. |
| `scenes/enemies/enemy.tscn` | Escena del enemigo (sprite tintado rojo, hurtbox, barra). |
| `tools/combo_smoke.gd` + `.tscn` | Test headless de combos/daño. |
| `tools/level_walk.gd` + `.tscn` | Test headless end-to-end en el nivel. |
| `tools/probe_space.gd` + `.tscn` | Sonda de colisión (mapa de zonas libres). |

### Archivos MODIFICADOS

| Archivo | Cambio |
|---|---|
| `project.godot` | +3 acciones de input (`attack_light`=H, `attack_medium`=J, `attack_heavy`=K). |
| `scenes/player/player.gd` | +hooks de combate (`begin_attack`, `end_attack`, `apply_attack_lunge`), getter `is_attacking`, movimiento bloqueado mientras ataca. |
| `scenes/player/player.tscn` | +nodo `AttackController`. (Nada más.) |
| `globals/signal_hub.gd` | +señales `enemy_health_changed`, `enemy_died`. |

> ⚠️ El archivo `ATTACK_COMBO_SYSTEM_PLAN.md` (en `Gj+2026Test/`) es el plan original largo. **Este** documento es el resumen de "qué se hizo y cómo funciona" para retomar el trabajo.

---

## 3. Qué cambió exactamente en cada archivo

### 3.1 `project.godot`
Se añadieron al `[input]`:
```
attack_light  -> tecla H (keycode 72)
attack_medium -> tecla J (keycode 74)
attack_heavy  -> tecla K (keycode 75)
```

### 3.2 `scenes/player/player.tscn`  ← (lo que preguntaste)
- Se añadió **un solo nodo**: `AttackController` (tipo `Node`) con el script `attack_controller.gd`.
- **No** se añadió un nodo de hitbox: la `AttackHitbox` (Area2D) la **crea el script en tiempo de ejecución** y la agrega como hija del Player (por eso no la ves en la escena).
- El nodo `Hitbox` viejo sigue ahí, **inerte** (`monitoring=false`, `collision_mask=0`). No se usa todavía; en el plan iba a reconvertirse en el "hurtbox del jugador" (para cuando el enemigo ataque).
- La animación `attack` y el `AnimationTree` **ya existían** y no se tocaron: mientras atacas, el controller **apaga el AnimationTree** y reproduce la animación `attack` desde el `AnimationPlayer` directamente.

### 3.3 `scenes/player/player.gd`
Se añadieron:
- `var _is_attacking`, y el getter `is_attacking`.
- `begin_attack(anim_name, anim_speed)` → marca atacando, apaga el `AnimationTree`, reproduce la animación.
- `end_attack()` → desmarca, restaura `speed_scale`, re-activa el `AnimationTree`.
- `apply_attack_lunge(direction, amount)` → pequeño empujón hacia adelante.
- En `_physics_process`, la lectura de input de movimiento ahora es:
  `if not _is_hurt and not _control_blocked and not _is_attacking:` → **no te puedes mover mientras atacas**.

### 3.4 `scenes/player/attack_controller.gd`  (el cerebro)
- `COMBO_TABLE`: diccionario `String -> AttackDefinition`.
- `TOKEN`: `action -> "H"/"J"/"K"`.
- `_buffer`: secuencia confirmada. `_pending`: input guardado durante un ataque.
- Crea la hitbox, la coloca según `hitbox_offset` y el `flip_h`, y la chequea dentro de la ventana activa.
- Nuevo: `@export var debug_log` + `_log()` que imprime `[COMBO] ...`.

### 3.5 `scenes/enemies/enemy.gd` / `enemy.tscn`
- `enemy.tscn`: `CharacterBody2D` en capa `enemy_body` (4), mascara `1`; un `Hurtbox` (Area2D) en capa `enemy_hitbox` (16) con cápsula; `HealthBar` (60).
- `enemy.gd`: `behavior` (TRAINING_DUMMY/FIGHTER), `health`, `take_hit()`, flash de color, knockback con fricción, `_die()`.
- **Fix importante:** antes el enemigo llamaba `move_and_slide()` **cada frame**, y al pararte encima lo **empujaba**. Ahora solo se mueve si tiene knockback real (`if _knockback.length_squared() > 1.0`).
- Nuevo: `@export var debug_log` + prints `[ENEMY] ...`.

### 3.6 `globals/signal_hub.gd`
- `signal enemy_health_changed(current, max)`, `signal enemy_died(enemy)` + sus `emit_...`.

---

## 4. Cómo funciona el sistema de combos (y tu pregunta del buffer)

### 4.1 Tu pregunta: ¿hay un buffer que guarda los movimientos?
**Sí, hay dos:**
- `_buffer` → la **secuencia confirmada** hasta ahora. Si vas `H` y luego `H`, `_buffer` pasa a `"HH"`.
- `_pending` → la tecla que pulsaste **mientras** ya estabas atacando. No se pierde: queda guardada y se encadena automáticamente en cuanto el ataque llega a su `cancel_time`.

Así, el juego sabe **si vas haciendo el combo bien** (el `_buffer` coincide con una entrada de `COMBO_TABLE`) o **mal** (no hay continuación → se reinicia la cadena con la nueva tecla).

### 4.2 Tabla de combos
```
H      -> jab
H,H    -> straight
H,H,H  -> hook
H,H,K  -> kick_finisher        (finisher)
H,H,H,K-> kick_finisher_big    (finisher)
J      -> heavy
K      -> kick
```

### 4.3 Algoritmo (por cada pulsación del token `T`)
1. `candidate = _buffer + T`.
2. Si `COMBO_TABLE` tiene `candidate` → **aciertas**, `_buffer = candidate`, y se juega ese movimiento.
3. Si no → **no es continuación válida** → `_buffer` se reinicia con `T` (o queda vacío) → se juega como ataque básico.
4. Si pasa tiempo sin teclas, la `combo_window` expira → `_buffer = ""` → la próxima pulsación es un **básico nuevo**.

### 4.4 Línea de tiempo de un ataque
```
   pulsar H
      │
      ▼
 [ windup ][ ACTIVE ][ recovery ........................ ]
      │        │          │
      │        │          └── desde cancel_time, la siguiente tecla CANCELA el recovery
      │        │              (encadena ya, sin esperar)
      │        └── aquí la hitbox está encendida (hit_delay .. hit_delay+hit_window)
      │
      └── si no pulsas antes de que acabe la animación:
             • tecla dentro de combo_window → sigue el combo (p. ej. HH -> straight)
             • sin tecla → el buffer se borra → la próxima H es un JAB nuevo
```

### 4.5 Tus observaciones, explicadas
- **"Los ataques hacen daño sin importar qué"** → Sí: cada pulsación *inicia un movimiento nuevo* con su hitbox activa. Lo que está limitado es que **un mismo golpe solo puede tocar a un enemigo una vez** (lista `_hit_targets`). Pulsar otra vez = nuevo golpe = nuevo daño. Eso es lo normal en un juego de combos.
- **"Si te quedas en la animación finalizando un puñetazo, aún puedes pulsar el mismo botón y hace daño"** → Correcto: esa tecla entra como `_pending` y, al llegar a `cancel_time`, encadena (`H` → `HH` → `HHH` …).
- **"No puedes solo pulsar el mismo botón y atacar inmediatamente… tienes que esperar"** → Exacto, y es **a propósito**: entre golpes encadenados hay que esperar al menos `cancel_time` (0.14 s para el jab). Ese es el "ritmo" del combo. Si lo quieres más rápido/suave, se baja `cancel_time` (ver §6).
- **"Los ataques repiten la animación"** → Sí, porque hoy todos usan la **misma** animación `attack` con distinto `speed_scale` (decisión D1a). Con animaciones propias (Fase 6) se verá como puñetazo → gancho → patada.

### 4.6 Hitbox / Hurtbox (capas)
| Nodo | Tipo | layer | mask | Activo |
|---|---|---|---|---|
| `AttackHitbox` (creada en código) | Area2D | `player_attack` (64) | `enemy_hitbox` (16) | solo en la ventana activa |
| Enemigo `Hurtbox` | Area2D | `enemy_hitbox` (16) | 0 | siempre (pasivo) |

La hitbox tiene la forma/posición tomadas del `AttackDefinition` (`hitbox_offset`, `hitbox_size`), y el offset en X se multiplica por la dirección (`flip_h`).

---

## 5. Los prints en consola (cómo saber si hiciste el combo)

Los logs se imprimen en el panel **Output** de Godot (abajo). Tienen dos etiquetas:
- `[COMBO]` → el jugador (secuencia, buffer, match, hit).
- `[ENEMY]` → el enemigo (daño recibido, vida, muerte).

**Formato de cada línea:**

| Línea | Significado |
|---|---|
| `[COMBO] IN  press 'H'  buffer=''  attacking=false` | Pulsaste H; no estabas atacando; buffer vacío. |
| `[COMBO] MATCH 'H' -> jab` | Encajó en la tabla → juega `jab`. |
| `[COMBO] MATCH 'HHK' -> kick_finisher  *** COMBO! ***` | **Combo completado** (un finisher). |
| `[COMBO] NO continuation for 'HJ' -> chain reset` | Secuencia inválida → la cadena se reinició. |
| `[COMBO]     buffered as _pending='K' (will chain at cancel_time 0.18s)` | Pulsaste mientras atacabas; se guardó para encadenar. |
| `[COMBO]     PLAY hook  (chain 'HHH', window 0.40s, cancel 0.18s)` | Empezó el movimiento. |
| `[COMBO]     HIT Enemy with hook (dmg 6)` | Golpe conectado. |
| `[COMBO]     END straight (buffer='HH', pending='')` | Terminó el movimiento. |
| `[COMBO] combo window EXPIRED -> buffer 'HH' cleared (next press = fresh basic)` | Se pasó el tiempo → próximo botón = básico nuevo. |
| `[ENEMY] Enemy took 9 (kick_finisher) -> hp 51/60` | Daño real aplicado a la vida. |

**Ejemplo de un `H,H,K` bien hecho:**
```
[COMBO] IN  press 'H'   buffer=''   attacking=false
[COMBO] MATCH 'H' -> jab
[COMBO]     PLAY jab   (chain 'H', window 0.35s, cancel 0.14s)
[COMBO]     HIT Enemy with jab (dmg 4)
[ENEMY] Enemy took 4 (jab) -> hp 56/60
[COMBO] IN  press 'H'   buffer='H'   attacking=true
[COMBO]     buffered as _pending='H' (will chain at cancel_time 0.14s)
[COMBO] MATCH 'HH' -> straight
[COMBO]     HIT Enemy with straight (dmg 5)
[ENEMY] Enemy took 5 (straight) -> hp 51/60
[COMBO] IN  press 'K'   buffer='HH'   attacking=true
[COMBO]     buffered as _pending='K' (will chain at cancel_time 0.16s)
[COMBO] MATCH 'HHK' -> kick_finisher   *** COMBO! ***
[COMBO]     HIT Enemy with kick_finisher (dmg 9)
[ENEMY] Enemy took 9 (kick_finisher) -> hp 42/60
```

### Plan del print (qué se añadió y por qué)
- Un único helper `_log()` en `AttackController` → todas las líneas salen con prefijo `[COMBO]` y se pueden **silenciar** con el check `debug_log` del Inspector (Player → AttackController).
- Eventos cubiertos: **input**, **buffer/pending**, **match / no-continuation**, **play**, **hit**, **end**, **expiración de ventana**.
- En el enemigo, `take_hit` y `_die` imprimen `[ENEMY] ...`.
- `_is_finisher(seq)` marca con `*** COMBO! ***` cuando la secuencia es un **final** (no un prefijo de un combo más largo). Así ves de un vistazo si "cerraste" el combo.
- Para silenciar todo: poner `debug_log = false` en el Inspector de `AttackController` (y del enemigo) o cambiar el default en el script.

> Nota: los prints son de depuración. Antes de una build final conviene apagar `debug_log`.

---

## 6. Tus observaciones → perillas de tuning

Si quieres que se sienta distinto, estos son los números a mover (en `resources/attacks/*.tres` y en `attack_controller.gd`):

| Sensación que quieres | Qué tocar |
|---|---|
| Encadenar **más rápido** (mashing más responsivo) | Bajar `cancel_time` en los `.tres`. |
| Que un combo se pueda hacer **más lento** todavía | Subir `combo_window`. |
| Que los básicos **no** encadenen tan fácil | Bajar `combo_window`. |
| Golpes con más "peso" | Subir `hitstun` y `knockback`. |
| Que el finisher **vuele** de verdad | `launch` (requiere Fase 3). |
| Golpe más largo (alcance) | `hitbox_size` y `hitbox_offset` en el `.tres`. |
| Que el jugador avance más al golpe | `lunge`. |

**Combo repetido del mismo botón:** hoy `H` repetido **sí** encadena (`H` → `HH` → `HHH`), pero con espera de `cancel_time`. Si quieres un "jab rápido" al machacar el mismo botón sin esperar, hay que añadir una **regla nueva** (p. ej. permitir cancelar más pronto entre golpes idénticos, o un combo `H,H,H,H`). Eso es una decisión de diseño, no un bug.

---

## 7. Investigación: cómo funcionan los combos (links + resúmenes)

Material de referencia para construir tu propio `.md`. Los conceptos clave son: **input buffering**, **cancel windows**, **hitstun** y **hitstop**.

### Conceptos
- **Input buffer**: guardar las pulsaciones durante unos frames (o durante una animación) para no perderlas; se ejecutan en cuanto se puede. Es lo que hace que los combos se sientan responsivos.
- **Cancel window / early cancel**: a partir de cierto frame del ataque, el siguiente input puede interrumpir el recovery y empezar el siguiente golpe. Es la clave de "encadenar rápido". *(En este proyecto = `cancel_time`.)*
- **Combo window / link window**: ventana tras el ataque en la que un input todavía cuenta como continuación; después se reinicia. *(Aquí = `combo_window`.)*
- **Hitstun**: tiempo en que el enemigo golpeado no puede actuar; más hitstun = más fácil encadenar.
- **Hitstop / hit freeze**: micro-pausa al conectar; da "peso" (aún no implementado aquí; `hitstop` existe en los `.tres` pero vale 0).
- **Dial-a-combo**: encadenar pulsando la secuencia; unos juegos cancelan el recovery (más rápido), otros esperan a que acabe la animación y usan buffer.

### Links
➡️ **La lista grande de links, con resúmenes largos y teoría de diseño, se movió a un documento aparte:**

**`COMBOS_RESEARCH.md`** (en la raíz del workspace) — *Combos Research & Design Bible*.

Contiene: la anatomía de un ataque, hitstun / hitstop / frame advantage, cómo funciona el input buffering (con sizing de ventanas y patrones de implementación en Godot), cancel windows y dial-a-combo, el mapa "parámetro → sensación" para este proyecto, patrones de implementación, y **la biblioteca anotada de fuentes** (con ⭐ de prioridad y qué leer según lo que quieras resolver).

---

## 8. Tabla de ajuste actual de los movimientos

(Copiado de los `.tres` — todos los tiempos en segundos; `launch` = velocidad vertical inicial px/s.)

| Input | Movimiento | Anim (speed) | Daño | hit_delay | hit_window | cancel_time | combo_window | hitstun | knockback.x | launch |
|---|---|---|---|---|---|---|---|---|---|---|
| `H` | jab | attack ×1.4 | 4 | 0.10 | 0.08 | 0.14 | 0.35 | 0.18 | 60 | 0 |
| `H,H` | straight | attack ×1.2 | 5 | 0.10 | 0.08 | 0.16 | 0.35 | 0.20 | 90 | 0 |
| `H,H,H` | hook | attack ×1.0 | 6 | 0.14 | 0.10 | 0.18 | 0.40 | 0.22 | 120 | 0 |
| `H,H,K` | kick_finisher | attack ×0.9 | 9 | 0.16 | 0.12 | 0.20 | 0.00 | 0.35 | 160 | 380 |
| `H,H,H,K` | kick_finisher_big | attack ×0.85 | 14 | 0.18 | 0.14 | 0.22 | 0.00 | 0.50 | 220 | 470 |
| `J` | heavy | attack ×0.7 | 10 | 0.22 | 0.12 | 0.22 | 0.30 | 0.30 | 140 | 120 |
| `K` | kick | attack ×0.9 | 8 | 0.16 | 0.12 | 0.20 | 0.30 | 0.30 | 150 | 250 |

Daños de combo verificados: `H,H,K` = 4+5+9 = **18**; `H,H,H,K` = 4+5+6+14 = **29**.

---

## 9. Cómo probar (checklist)

Abrir `scenes/level/test/test_level.tscn` y ejecutar (F5). Los muñecos están junto al spawn:
`Enemy1 (112,224)`, `Enemy2 (176,224)`, `Enemy3 (240,224)`; el jugador aparece en `(240,176)` (baja o muévete a la izquierda para llegar).

- [ ] `H` suelto → jab (aunque repitas lento).
- [ ] `H,H` rápido → jab → straight.
- [ ] `H,H,K` rápido → jab → straight → kick finisher.
- [ ] `H,H,H,K` rápido → … → big finisher.
- [ ] Pulsaciones **lentas** → solo jab (el buffer se borra).
- [ ] Input **durante** el ataque → se encadena igual (queda como `_pending`).
- [ ] Continuación inválida (`H,J`) → empieza limpio con `J`.
- [ ] Un mismo golpe golpea a cada enemigo **una vez**.
- [ ] El muñeco **no se mueve** al caminar contra él (fix aplicado).
- [ ] La consola muestra las líneas `[COMBO]` / `[ENEMY]` correctas.

> Los scripts `tools/combo_smoke.tscn` y `tools/level_walk.tscn` son tests automáticos headless
> (`flatpak run org.godotengine.Godot --headless --path <ruta> res://tools/combo_smoke.tscn`).
> `tools/probe_space.tscn` imprime un mapa de zonas libres de colisión.

---

## 10. Próximos pasos (propuesta)

1. **Fase 3 — reacciones:** estados `HURT / LAUNCHED / KNOCKDOWN / GETUP / DEAD` con gravedad, para que los finishers lancen y el muñeco se levante.
2. **Fase 5 — IA de peleador:** `behavior = FIGHTER` (perseguir + atacar), y hitbox de enemigo que dañe al jugador.
3. **Animaciones propias** (punch/gancho/patada) para que cada golpe se vea distinto.
4. **Tuning de "feel"** contigo: sobre todo `cancel_time` y `combo_window`.
5. Opcional: un contador de combo en pantalla (además de los prints de consola).

### Decisiones abiertas
- ¿Quieres un **jab rápido** al machacar el mismo botón (sin esperar `cancel_time`)?
- ¿Los finishers deben **lanzar** (volar) o basta con el empuje actual?
- ¿Silenciamos los prints o los dejamos encendidos durante el desarrollo? (hoy: encendidos).

---

## 11. Glosario rápido
- **Token**: la letra del botón (`H`/`J`/`K`).
- **Buffer (`_buffer`)**: secuencia confirmada.
- **Pending (`_pending`)**: tecla guardada durante un ataque.
- **cancel_time**: desde aquí, el siguiente input interrumpe el recovery.
- **combo_window**: tiempo tras el ataque para encadenar antes de resetear.
- **hit_delay / hit_window**: cuándo se enciende la hitbox.
- **hitstun / hitstop**: aturdimiento del enemigo / micro-pausa al conectar.
- **lunge**: pequeño paso hacia adelante al golpear.
