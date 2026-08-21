# R-Type Mobile (Godot 4.5)

A dynamic, side-scrolling sci-fi shoot-'em-up game built in **Godot 4.5+ (GDScript)** tailored for mobile (Samsung Galaxy S24+ / 1920×1080 landscape) and desktop pair-programming with Google DeepMind's **Antigravity** AI assistant.

---

## 🚀 Quick Start (For Antigravity & New PC Setup)

### 1. Requirements
- **Godot Engine:** Version `4.5.1-stable` or higher (Standard Win64/macOS/Linux build, GDScript).
- **Python 3.10+ (with Pillow):** Required for local asset processing pipeline (`pip install pillow`).
- **Git:** Version 2.40+.

### 2. Clone the Repository
```bash
git clone https://github.com/b6-stack/rtype-game.git
cd rtype-game
```

### 3. Open in Godot
- Launch Godot 4.5+.
- Click **Import**, navigate to the cloned `rtype-game` folder, and select `project.godot`.
- Press **F5** (or Run Project) to start from the Main Menu (`res://scenes/main_menu/MainMenu.tscn`).

---

## 🎮 Gameplay & Controls

### Mobile (Target Device: Samsung Galaxy S24+)
- **Single-Finger Touch & Drag:** Moves the player ship freely across the screen. Primary weapon **only fires while a finger touches the screen**.
- **Second-Finger Hold:** Charges the secondary weapon (fills the on-screen charge meter).
- **Second-Finger Release:** Discharges the high-energy charged volley.
- **Lifting All Fingers:** Immediately ceases firing to allow peaceful navigation.

### Desktop / Editor Testing (PC Fallback)
- **Mouse Left-Click & Drag:** Move ship and fire primary weapon.
- **Mouse Right-Click / Middle-Click / 'Z' Key:** Hold to charge weapon; release to fire charged shot.
- **Keyboard (WASD / Arrow Keys):** High-speed 8-directional ship navigation (`650 px/s`).
- **Escape / 'P' Key:** Toggle Pause Menu.

---

## 🌟 Key Features & Systems

### 1. Weapon Arsenal (10 Distinct Weapon Classes)
Every weapon features unique primary firing characteristics and charged attacks:
1. **Vulcan Cannon (V):** Rapid single plasma bolts. *Charge:* Focused 3-bullet spread volley.
2. **Laser Beam (L):** Concentrated high-velocity piercing beam. *Charge:* Dual heavy parallel lasers.
3. **Plasma Orb (P):** Heavy energy spheres. *Charge:* High-density condensed plasma blast.
4. **Homing Missile (M):** Heat-seeking micro-rockets. *Charge:* Multi-missile swarm lock-on.
5. **Wave Pulse (W):** Dual oscillating sine-wave energy pulses. *Charge:* High-amplitude wave sweep.
6. **Bouncer (B):** Ricocheting rounds that reflect off terrain walls. *Charge:* 3-way wall bounce barrage.
7. **Drill Cannon (D):** High-velocity piercing shell. *Charge:* Mega-drill rail shot.
8. **Ricochet Cluster (R):** Bullets that fragment into spread shrapnel upon impact. *Charge:* Cluster bomb.
9. **Gravity Singularity (G):** Singularity sphere pulling nearby hostiles toward its vortex. *Charge:* Mega-singularity.
10. **Chain Lightning (Z):** Electrical discharge jumping between nearest hostiles. *Charge:* 3-arc lightning storm.

### 2. Hostile Bestiary (20 Enemy Types)
Covering 6 distinct visual sprite archetypes with custom AI personalities:
- `EnemyGrunt`, `EnemyWeaver`, `EnemyDiver`, `EnemySniper`, `EnemySpreader`, `EnemyTurret`, `EnemyShield`, `EnemyZigzag`, `EnemyBomber`, `EnemyStalker`, `EnemyCircler`, `EnemyKamikaze`, `EnemyCloaker`, `EnemySplitter`, `EnemyCharger`, `EnemyTanker`, `EnemyFormation`, `EnemyBoomerang`, `EnemyLeech`, `EnemyOverseer`.

### 3. Boss Encounters (10 Levels / 10 Bosses)
- Level 1: `BossIronClaw`
- Level 2: `BossHydra` (Multi-head destruction)
- Level 3: `BossBehemoth` (Heavy ramming charges)
- Level 4: `BossSentinel` (Rotating shield segments)
- Level 5: `BossSwarmQueen` (Continuous enemy spawning)
- Level 6: `BossPhotonCore` (Sweeping laser arcs)
- Level 7: `BossAbyssGate` (Teleportation & gravity wells)
- Level 8: `BossOmega` (Multi-phase ultimate boss)
- Level 9: `BossDreadStar`
- Level 10: `BossHyperion`

### 4. Dynamic Procedural Modular Landscape
- **100% Safe Corridor Guarantee:** Seeded random-walk algorithm enforces a wide safe corridor (`>= 260px` clearance) with zero dead ends.
- **Physical Collision:** Top and bottom walls feature `StaticBody2D` + `CollisionPolygon2D` geometry. Crashing into landscape damages the player and costs a life point.
- **Infinite Streaming:** Seamless chunk stitching (`Chunk.gd`) with 2px geometric overlap guarantees zero visual gaps across endless play and boss fights.
- **10 Biome Themes:** Unique cavern palettes and glowing circuit trims tailored for each of the 10 levels.

### 5. Progression & Power-Up Drops
- **Score Goal 1-UP Bar:** Earning points continuously fills the HUD 1-UP progress meter. Every **5,000 points** awards an extra life point.
- **Kill-Based Drop Table:**
  - **1-UP Life Capsule (+1 Life):** `1.5%` chance on enemy kill.
  - **Super Shield Orb (6s Invincibility):** `2.5%` chance on enemy kill.
  - **Weapon Upgrade Capsule:** `6.0%` chance on enemy kill (100% guaranteed on boss defeat).
- **Safe Respawn:** When damaged with lives remaining, the player safely respawns in the open center corridor, wipes on-screen hostile bullets, and receives **3.0 seconds of invincibility** with a rotating cyan force-field.

---

## 📁 Project Architecture

```
rtype-game/
├── assets/
│   └── sprites/               # Processed transparent game PNGs
├── autoloads/
│   ├── GameState.gd           # Global singleton (score, lives, level, weapon, 1-UP goals)
│   └── InputManager.gd        # Multi-touch & desktop mouse/keyboard input coordinator
├── resources/
│   ├── bosses/                # BossData .tres resource files
│   ├── enemies/               # EnemyData .tres resource files
│   └── weapons/               # WeaponData .tres resource files
├── scenes/
│   ├── bosses/                # BossBase.tscn, BossManager.gd, Boss*.gd
│   ├── effects/               # ExplosionFX.tscn, PickupFX.gd
│   ├── enemies/               # EnemyBase.tscn, EnemySpawner.gd, Enemy*.gd
│   ├── game/                  # Game.tscn (orchestrator), HUD/, PauseMenu/, GameOver/, WinScreen/
│   ├── main_menu/             # MainMenu.tscn, StarContainer.gd
│   ├── player/                # Player.tscn, Player.gd, weapons/ (Bullet.tscn, Weapon*.gd)
│   ├── powerups/              # PowerUp.tscn, PowerUp.gd, PowerUpSpawner.gd
│   └── world/                 # Chunk.tscn, LevelGenerator.gd, ScrollingBackground.tscn
├── process_art.py             # PIL transparency flood-fill & auto-crop utility
└── project.godot              # Godot 4.5 configuration
```

---

## 🤖 Antigravity AI Agent Instructions

When developing or debugging this project with an Antigravity agent:
1. **Headless Verification:** Always verify script compilation and engine sanity via Godot console:
   ```powershell
   & "<path-to-godot>_console.exe" --headless res://scenes/game/Game.tscn
   ```
2. **Re-importing Assets:** When new sprites are added to `assets/sprites/`, refresh metadata via:
   ```powershell
   & "<path-to-godot>_console.exe" --headless --editor --quit
   ```
3. **Art Pipeline:** Generate sprites on pure magenta `#FF00FF` background without outside glow or drop shadows, then run `python process_art.py <input.jpg> <output.png>`.
4. **GDScript Typing:** Avoid ambiguous `:=` assignments from `Variant` returns; specify explicit types `var x: Type = ...` to prevent parser warnings.
