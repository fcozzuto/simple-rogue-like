# Simple Rogue-like — Game Design Document

**Version:** 1.2  
**Date:** March 2026  
**Engine:** Godot 4.x (GDScript)  
**Format:** 3D Isometric View (perspective camera)  

---

## Table of Contents

1. [Game Overview](#1-game-overview)
2. [Visual & Rendering](#2-visual--rendering-specification)
3. [Player Specification](#3-player-specification)
4. [Enemy Specification](#4-enemy-specification)
5. [Projectile Specification](#5-projectile-specification)
6. [Items & Power-Ups](#6-items--power-ups)
7. [Level Design](#7-level-design)
8. [User Interface](#8-user-interface)
9. [Technical Specifications](#9-technical-specifications)
10. [Game Flow](#10-game-flow)
11. [Post-MVP Roadmap](#11-future-considerations-post-mvp)
12. [Review Checklist](#12-review-checklist)

---

## 1. Game Overview

| Field | Description |
|-------|-------------|
| **Title** | Simple Rogue-like |
| **Engine** | Godot 4.x (GDScript) |
| **Format** | 3D Isometric View (perspective camera) |
| **Genre** | Action Roguelike (real-time combat) |
| **Target Platform** | PC (Windows/macOS/Linux) |
| **Scope** | MVP — Single arena, core mechanics |

---

## 2. Visual & Rendering Specification

### 2.1 Scene Setup

| Element | Configuration |
|---------|---------------|
| **Camera Type** | Perspective |
| **FOV** | 50° |
| **Camera Angle** | Y: 45°, X: 35.264° (isometric view angle) |
| **Camera Controls** | Follows player smoothly (lerp 0.1) |
| **Lighting** | 1x DirectionalLight3D (sun), 1x OmniLight3D (ambient fill) |
| **Environment** | Dark moody atmosphere, fog disabled |
| **Background** | Solid dark color `#1a1a2e` |

### 2.2 Color Palette

| Element | Hex Color | Description |
|---------|-----------|-------------|
| Background | `#1a1a2e` | Deep navy |
| Floor | `#2d2d44` | Dark slate |
| Walls | `#16213e` | Midnight blue |
| Player | `#00ff88` | Neon green (emissive) |
| Turret | `#ff4444` | Red |
| Chaser | `#ff8800` | Orange (emissive) |
| Player Projectile | `#00ffff` | Cyan (emissive) |
| Enemy Projectile | `#ff0066` | Hot pink (emissive) |
| Health Potion | `#00ff00` | Bright green (emissive) |
| Weapon Pickup | `#ffff00` | Yellow (emissive) |
| Power-Up Cards | Various | Per power-up (see Section 6.2) |

### 2.3 3D Assets (Primitives Only)

| Entity | Shape | Dimensions |
|--------|-------|------------|
| Player | CapsuleMesh | radius 0.4, height 1.8 |
| Turret | CylinderMesh + BoxMesh (base) | h 1.0, r 0.5 |
| Chaser | SphereMesh | r 0.5 |
| Walls | BoxMesh | 1x2x(arbitrary length) |
| Floor | PlaneMesh | 30x30 units |
| Projectile | SphereMesh | r 0.15 |
| Health Potion | CylinderMesh | h 0.3, r 0.2 |
| Weapon Pickup | BoxMesh | 0.3x0.1x0.3 |

---

## 3. Player Specification

### 3.1 Base Properties

| Attribute | Base Value | Source |
|-----------|------------|--------|
| **Health** | 100 HP | Base |
| **Max Health** | 100 HP | Base |
| **Movement Speed** | 6 units/second | Base |
| **Melee Range** | 2.0 units | Base |
| **Melee Damage** | 35 HP | Base |
| **Melee Cooldown** | 0.4 seconds | Base |
| **Base Ranged Damage** | 20 HP | Base |
| **Ranged Speed** | 22 units/second | Base |
| **Ranged Cooldown** | 0.6 seconds | Base |
| **Dodge Distance** | 3.5 units | Base |
| **Dodge Duration** | 0.25 seconds | Base |
| **Dodge Cooldown** | 1.5 seconds | Base |

> **Note:** Player stats can be permanently modified by power-ups (see Section 6.2).

### 3.2 Scoring

| Source | Points |
|--------|--------|
| Turret Kill | +100 |
| Chaser Kill | +50 |
| Survival Bonus | +10 per second survived |

### 3.3 Controls

| Action | Input |
|--------|-------|
| Move Forward | W |
| Move Backward | S |
| Move Left | A |
| Move Right | D |
| Dodge | Spacebar |
| Melee Attack | Left Mouse Button |
| Ranged Attack | Right Mouse Button |
| Aim Direction | Mouse Position (crosshair follows mouse) |
| Restart (when dead) | R |
| Select Power-Up | Left Mouse Click on card |

### 3.4 Player Logic

1. **Movement**: `CharacterBody3D` with `move_and_slide()`. WASD applies velocity in camera-relative directions.
2. **Aiming**: Crosshair follows mouse position. Player mesh smoothly rotates to face the crosshair (lerp factor 0.15).
3. **Dodge**: On Space press (if not on cooldown):
   - If movement input active: dash in movement direction
   - If no movement input: dash backward (opposite of facing direction)
   - Dash distance: 3.5 units over 0.25 seconds
   - Cooldown: 1.5 seconds
   - **Invincibility**: Player is invulnerable during dodge (projectiles pass through)
4. **Melee Attack**: On LMB press, if any enemy within 2 units in facing direction, deal damage immediately. 0.4s cooldown.
5. **Ranged Attack**: On RMB press, spawn projectile at player position, traveling toward crosshair direction. 0.6s cooldown.
6. **Taking Damage**: On enemy projectile hit or enemy contact, subtract HP. If HP ≤ 0, trigger death state.
7. **Death State**: Freeze player, display "YOU DIED" text, show final score, show "Press R to Restart" prompt.
8. **Scoring**: Accumulate points from kills and survival time. Display in UI.

---

## 4. Enemy Specification

### 4.1 Turret

| Attribute | Value |
|-----------|-------|
| **Health** | 80 HP |
| **Detection Range** | 18 units |
| **Rotation Speed** | 2.0 rad/second |
| **Fire Rate** | 1 shot per 2.0 seconds |
| **Projectile Speed** | 14 units/second |
| **Projectile Damage** | 12 HP |
| **Color** | Red `#ff4444` |

**Behavior:**
1. Only activates when player is within 18 units.
2. When active: rotates to face player position (smooth interpolation).
3. When facing player (within 5° tolerance), fires projectile.
4. Projectile travels in straight line.
5. On death: `queue_free()`, no loot.

### 4.2 Chaser

| Attribute | Value |
|-----------|-------|
| **Health** | 50 HP |
| **Movement Speed** | 3.5 units/second |
| **Detection Range** | 8 units |
| **Contact Damage** | 15 HP (cooldown 1.0s) |
| **Color** | Orange `#ff8800` |

**Behavior:**
1. If player distance > 8 units: idle (stationary).
2. If player distance ≤ 8 units: move directly toward player.
3. On contact with player (within 0.8 units): deal damage, trigger 1.0s cooldown.
4. On death: `queue_free()`, chance to drop health potion (20%).

---

## 5. Projectile Specification

| Owner | Speed | Damage | Lifespan | Collision |
|-------|-------|--------|----------|-----------|
| Player | 22 u/s | 20 HP (base) | 3.0 seconds | Destroys on enemy hit |
| Turret | 14 u/s | 12 HP | 5.0 seconds | Destroys on floor/wall hit |

**Behavior:**
- Travel in straight line (direction set at spawn).
- `Area3D` for collision detection.
- On hit: apply damage, destroy self.
- On wall/floor: destroy self.

---

## 6. Items & Power-Ups

### 6.1 Arena Items

| Item | Effect | Visual | Pickup Trigger |
|------|--------|--------|----------------|
| **Health Potion** | Restore 30 HP (cap at max) | Green glowing cylinder | Player `Area3D` overlap |
| **Weapon Upgrade** | +15 ranged damage (permanent) | Yellow glowing box | Player `Area3D` overlap |

### 6.2 Power-Up Pool

Power-ups are offered after completing a level. The player chooses 1 of 3 randomly selected power-ups.

| Power-Up | Effect | Icon Color |
|----------|--------|------------|
| **Vitality** | +25 max HP (heals to full too) | Red `#ff4444` |
| **Swift Feet** | +1.5 movement speed | Blue `#4444ff` |
| **Sharp Blade** | +10 melee damage | Orange `#ff8800` |
| **Quick Shot** | -0.15 ranged cooldown | Cyan `#00ffff` |
| **Iron Skin** | -15% damage taken | Gray `#888888` |
| **Regeneration** | Heal 5 HP every 3 seconds | Green `#00ff00` |
| **Swift Dodge** | -0.4s dodge cooldown | Purple `#aa44ff` |

### 6.3 Power-Up Selection Rules

| Condition | Power-Up Available? |
|-----------|---------------------|
| Level Complete | Yes — choose 1 of 3 random |
| Player Death | No — restart with base stats |

---

## 7. Level Design

### 7.1 Arena Layout (Level 1)

```
+------------------------------------------+
|                                          |
|   [T]                         [T]        |
|                                          |
|                                          |
|       [C]              [C]               |
|                                          |
|   [P]        [HP]           [W]          |
|                    [C]                   |
|                                          |
|                                          |
+------------------------------------------+
```

### 7.2 Entity Positions

| Symbol | Entity | Position (x, z) |
|--------|--------|-----------------|
| [T] | Turret | (-10, -10), (10, -10) |
| [C] | Chaser | (-5, 0), (5, 0), (0, 5) |
| [P] | Player Spawn | (-12, 0) |
| [HP] | Health Potion | (0, -5) |
| [W] | Weapon Upgrade | (10, 5) |

### 7.3 Boundaries

- Floor: 30x30 unit plane
- Walls: 4 walls, height 3 units, thickness 1 unit
- No internal obstacles in MVP

---

## 8. User Interface

### 8.1 HUD Elements

| Element | Position | Style |
|---------|----------|-------|
| Health Bar | Top-left (20px, 20px) | 200x20px, green fill on dark bg |
| Health Text | Above health bar | "HP: 75/100" |
| Dodge Cooldown | Below health bar | 150x10px, blue fill (empty when ready) |
| Score | Top-right (20px from right, 20px from top) | "Score: 1250" |
| Level | Below score | "Level: 1" |
| Crosshair | Follows mouse cursor | 8px white dot, 70% opacity |

### 8.2 Game Over Screen

- Dark overlay (50% black)
- "YOU DIED" text (center, large, red)
- "Final Score: XXXX" (below, white)
- "Press R to Restart" (below, smaller, white)

### 8.3 Power-Up Selection Screen

| Element | Description |
|---------|-------------|
| Background | Dark overlay (70% black) |
| Title | "LEVEL COMPLETE" (center top, large, gold) |
| Score | "Score: XXXX" (below title) |
| Cards | 3 power-up cards displayed horizontally, center screen |
| Card Style | Bordered box with icon color, name, and description |
| Selection | Click card to select, advances to next level |

---

## 9. Technical Specifications

### 9.1 Node Structure

```
main (Node3D)
├── Environment
├── DirectionalLight3D
├── Floor (MeshInstance3D)
├── Walls (Node3D)
│   ├── WallNorth (MeshInstance3D)
│   ├── WallSouth (MeshInstance3D)
│   ├── WallEast (MeshInstance3D)
│   └── WallWest (MeshInstance3D)
├── PlayerSpawnPoint (Marker3D)
├── Player (CharacterBody3D)
├── Turrets (Node3D)
│   ├── Turret1
│   └── Turret2
├── Chasers (Node3D)
│   ├── Chaser1
│   ├── Chaser2
│   └── Chaser3
├── Items (Node3D)
│   ├── HealthPotion
│   └── WeaponUpgrade
├── Projectiles (Node3D)  [dynamic]
└── UI (CanvasLayer)
	├── HealthBar (TextureProgressBar)
	├── ScoreLabel (Label)
	├── LevelLabel (Label)
	├── Crosshair (TextureRect)
	├── GameOver (Control, hidden)
	└── PowerUpScreen (Control, hidden)
```

### 9.2 Script Architecture

| Script | Inherits | Responsibilities |
|--------|----------|-----------------|
| `main.gd` | Node3D | Spawns entities, manages game state, level transitions |
| `player.gd` | CharacterBody3D | Movement, aiming, combat, health, power-up application |
| `turret.gd` | Node3D | Rotation tracking, firing logic |
| `chaser.gd` | CharacterBody3D | Movement AI, contact damage |
| `projectile.gd` | Area3D | Travel, collision, damage |
| `item.gd` | Area3D | Pickup detection, effect application |
| `ui.gd` | CanvasLayer | Health bar, score, level, game over, power-up screen |
| `powerup.gd` | Control | Power-up card display and selection |

### 9.3 Input Map

| Action | Input |
|--------|-------|
| move_forward | W |
| move_backward | S |
| move_left | A |
| move_right | D |
| dodge | Spacebar |
| melee_attack | Left Mouse Button |
| ranged_attack | Right Mouse Button |
| restart | R |

### 9.4 File Structure

```
simple-rougue-like/
├── project.godot
├── GDD.md
├── scenes/
│   ├── main.tscn                    (root scene)
│   ├── player.tscn                  (player prefab)
│   ├── turret.tscn                  (turret prefab)
│   ├── chaser.tscn                  (chaser prefab)
│   ├── projectile.tscn               (projectile prefab)
│   └── item.tscn                    (item prefab)
├── scripts/
│   ├── main.gd
│   ├── player.gd
│   ├── turret.gd
│   ├── chaser.gd
│   ├── projectile.gd
│   ├── item.gd
│   ├── ui.gd
│   └── powerup.gd
└── materials/
	└── (placeholder colors, no textures)
```

---

## 10. Game Flow

```
[START]
	↓
[INIT] Load main.tscn, spawn Level 1 entities
	↓
[GAME LOOP]
	├── Player moves (WASD)
	├── Player aims (mouse, smooth rotation)
	├── Player attacks (LMB/RMB)
	├── Turrets rotate and fire
	├── Chasers chase/attack
	├── Projectiles travel and collide
	├── Items checked for pickup
	├── Score updated (+kill points, +survival bonus)
	└── UI updated
	↓
[CHECK] Any end condition?
	│
	├── Player HP ≤ 0
	│   → [GAME OVER]
	│       ├── Show final score
	│       ├── No power-up offered
	│       └── Wait for R → restart Level 1 (base stats)
	│
	└── All enemies dead
		→ [LEVEL COMPLETE]
			├── Show score
			├── Generate 3 random power-ups
			├── [POWER-UP SELECTION]
			│       └── Player clicks one card
			├── Apply selected power-up to player stats
			└── Spawn next level
```

---

## 11. Future Considerations (Post-MVP)

| Feature | Description |
|---------|-------------|
| **Multiple Floors** | Procedural dungeon generation with increasing difficulty |
| **Enemy Variety** | Fast chasers, heavy turrets, ranged enemies |
| **Equipment Slots** | Armor, accessories (in addition to power-ups) |
| **Potion Inventory** | Hotkey-activated potions during gameplay |
| **Save/Load System** | Persist progress and power-ups between sessions |
| **Audio** | Sound effects and music |
| **VFX** | Particle effects for hits/attacks |
| **Enemy Scaling** | More/faster/tougher enemies per level |

---

## 12. Review Checklist

> **Status:** Updated for v1.2 — Awaiting Approval

| # | Question | Answer |
|---|----------|--------|
| 1 | Camera type | Perspective with isometric angle |
| 2 | Player rotation | Smooth rotation (lerp 0.15) |
| 3 | Death/restart | Press R to restart |
| 4 | Scoring | Track kills (100/50) + survival (+10/sec) |
| 5 | Victory condition | Level complete → power-up selection → next level |
| 6 | Dodge | Spacebar (dash with i-frames) |
| 7 | Turret detection | 18 units (not infinite) |
| 8 | Crosshair | Follows mouse cursor |

### Implementation Readiness Checklist

- [ ] GDD reviewed and approved
- [ ] All questions answered
- [ ] Ready to proceed with implementation

---

*Document Version: 1.2 — Changes from v1.1:*
- *Section 3.1: Added dodge stats (distance, duration, cooldown)*
- *Section 3.3: Added dodge control (Spacebar)*
- *Section 3.4: Added dodge mechanic with invincibility frames*
- *Section 4.1: Turret detection range changed from infinite to 18 units*
- *Section 6.2: Added "Swift Dodge" power-up*
- *Section 8.1: Crosshair now follows mouse cursor, added dodge cooldown bar*
- *Section 9.3: Added dodge to input map*

*Document Version: 1.1 — Changes from v1.0:*
- *Section 2.1: Camera changed to perspective (not orthographic)*
- *Section 3.2: Added scoring system*
- *Section 3.3: Player rotation changed to smooth (lerp 0.15)*
- *Section 3.4: Added survival bonus and scoring to logic*
- *Section 6.2: Added power-up pool (6 upgrades)*
- *Section 6.3: Added power-up selection rules*
- *Section 8.1: Added score and level to HUD*
- *Section 8.3: Added power-up selection screen*
- *Section 10: Updated game flow with win condition and power-up selection*
- *Section 9.2: Added powerup.gd script*
