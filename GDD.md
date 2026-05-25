# Simple Rogue-like - Game Design Document

**Version:** 1.3  
**Date:** May 2026  
**Engine:** Godot 4.6 (GDScript project)  
**Format:** 3D arena action roguelike with a fixed perspective camera

---

## Table of Contents

1. [Game Overview](#1-game-overview)
2. [Visual and Rendering Specification](#2-visual-and-rendering-specification)
3. [Player Specification](#3-player-specification)
4. [Enemy Specification](#4-enemy-specification)
5. [Projectile Specification](#5-projectile-specification)
6. [Items and Power-Ups](#6-items-and-power-ups)
7. [Level Design and Progression](#7-level-design-and-progression)
8. [User Interface](#8-user-interface)
9. [Technical Specifications](#9-technical-specifications)
10. [Game Flow](#10-game-flow)
11. [Future Considerations](#11-future-considerations)
12. [Review Checklist](#12-review-checklist)

---

## 1. Game Overview

| Field | Description |
|-------|-------------|
| **Title** | Simple Rogue-like |
| **Engine** | Godot 4.6 |
| **Genre** | Real-time arena action roguelike |
| **Platform** | PC |
| **View** | Perspective, fixed overhead angle |
| **Core Loop** | Clear all enemies, choose 1 of 3 power-ups, continue to next level |
| **Run Structure** | Single run with persistent upgrades until death or restart |

---

## 2. Visual and Rendering Specification

### 2.1 Scene Setup

| Element | Current Implementation |
|---------|------------------------|
| **Camera Type** | Perspective |
| **FOV** | 65 degrees |
| **Camera Behavior** | Static camera, does not follow player |
| **Camera Placement** | Positioned above and behind the arena at roughly `(0, 15, 18)` |
| **Lighting** | 1 `DirectionalLight3D` plus 1 `OmniLight3D` |
| **Environment** | Procedural sky, ambient light enabled, no fog |
| **Arena** | 30x30 floor with 4 perimeter walls |

### 2.2 Color Palette

| Element | Color |
|---------|-------|
| Floor | `#2d2d44` |
| Walls | `#16213e` |
| Player | `#00ff88` |
| Turret | `#ff4444` |
| Chaser | `#ff8800` |
| Player Projectile | `#00ffff` |
| Enemy Projectile | `#ff0066` |
| Health Potion | `#00ff00` |
| Weapon Upgrade | `#ffff00` |

### 2.3 Primitive Assets

| Entity | Shape |
|--------|-------|
| Player | Capsule |
| Turret | Cylinder body with box barrel |
| Chaser | Sphere |
| Walls | Box meshes |
| Floor | Plane mesh |
| Projectile | Small sphere |
| Health Potion | Small glowing cylinder |
| Weapon Upgrade | Small glowing box |

---

## 3. Player Specification

### 3.1 Base Properties

| Attribute | Base Value |
|-----------|------------|
| Health | 100 |
| Max Health | 100 |
| Move Speed | 6.0 |
| Melee Range | 2.0 |
| Melee Damage | 35 |
| Melee Cooldown | 0.4s |
| Melee Swing Duration | 0.14s |
| Ranged Damage | 20 |
| Ranged Speed | 22.0 |
| Ranged Cooldown | 0.6s |
| Dodge Distance | 3.5 |
| Dodge Duration | 0.25s |
| Dodge Cooldown | 1.5s |
| Damage Reduction | 0.0 by default |
| Regeneration | Off by default |

### 3.2 Scoring

| Source | Points |
|--------|--------|
| Turret Kill | +100 |
| Chaser Kill | +50 |
| Passive Survival | None |

Score is earned from gameplay actions only. There is no score-over-time mechanic.

### 3.3 Controls

| Action | Input |
|--------|-------|
| Move Forward | `W` |
| Move Backward | `S` |
| Move Left | `A` |
| Move Right | `D` |
| Dodge | `Space` |
| Melee Attack | Left Mouse Button |
| Ranged Attack | Right Mouse Button |
| Aim | Mouse cursor |
| Restart After Death | `R` |
| Select Power-Up | Left Mouse Button |

### 3.4 Player Logic

1. **Movement:** The player uses `CharacterBody3D` movement with `move_and_slide()`.
2. **Aiming:** The cursor is projected into the 3D world and the player rotates smoothly toward the aim point.
3. **Dodge:** If movement input is active, dodge uses the movement direction. If not, dodge uses the current facing direction. The player is invulnerable while dodging.
4. **Melee Attack:** Melee checks overlapping enemies in the melee area, applies immediate damage, plays a short weapon swing, and applies knockback to chasers.
5. **Melee Knockback:** Knockback strength increases as melee damage increases through power-ups.
6. **Ranged Attack:** Ranged projectiles spawn from the weapon muzzle and travel toward the current mouse aim point.
7. **Damage Handling:** Incoming damage is reduced by `damage_reduction` if the run has that upgrade.
8. **Death State:** On death, the player disables physics/input/collision, enemies are stopped, and the game over UI is shown.
9. **Persistent Run State:** Player upgrades are stored in run state and reapplied when a new level spawns a fresh player instance.

---

## 4. Enemy Specification

### 4.1 Turret

| Attribute | Base Value |
|-----------|------------|
| Health | 80 |
| Detection Range | 18.0 |
| Rotation Speed | 2.0 |
| Fire Interval | 2.0s |
| Projectile Speed | 14.0 |
| Projectile Damage | 12 |

**Behavior**

1. The turret becomes active when the player is within detection range.
2. It rotates toward the player each physics frame.
3. If it is roughly lined up with the player, it fires a projectile.
4. On death, it awards score and is removed.
5. Turrets do not drop loot.

### 4.2 Chaser

| Attribute | Base Value |
|-----------|------------|
| Health | 50 |
| Move Speed | 3.5 |
| Detection Range | 8.0 |
| Contact Damage | 15 |
| Contact Cooldown | 1.0s |

**Behavior**

1. If the player is outside detection range, the chaser idles.
2. If the player is inside detection range, the chaser moves directly toward the player.
3. If the chaser remains overlapping the player, it continues dealing damage on its cooldown.
4. Chasers can be pushed back by melee hits.
5. On death, the chaser awards score and has a 20% chance to drop a health potion.

---

## 5. Projectile Specification

| Projectile | Speed | Damage | Lifespan |
|------------|-------|--------|----------|
| Player Projectile | 22.0 base | 20 base | 3.0s |
| Turret Projectile | 14.0 base | 12 base | 3.0s |

### Current Behavior

1. Projectiles move in a straight line in world space.
2. Fast-hit detection uses a raycast between the current and next projectile position each frame.
3. Player projectiles damage enemies and are removed on hit.
4. Turret projectiles damage the player and are removed on hit.
5. Projectiles are also removed when they hit the arena bounds or expire.

---

## 6. Items and Power-Ups

### 6.1 Arena Items

| Item | Effect | Visual | How It Spawns |
|------|--------|--------|---------------|
| Health Potion | Restore 30 HP up to max | Green glowing cylinder | 1 placed in arena each level, plus chaser drop chance |
| Weapon Upgrade | +15 ranged damage for the current run | Yellow glowing box | 1 placed in arena each level |

Item pickup uses overlap with the player or player pickup area. Items also check immediate overlap after spawning so pickups dropped directly under the player still work.

### 6.2 Power-Up Pool

Power-ups are offered after the player clears a level. The game pauses and shows 3 random choices.

| Power-Up | Effect |
|----------|--------|
| Vitality | +25 max HP and heal to full |
| Swift Feet | +1.5 move speed |
| Sharp Blade | +10 melee damage |
| Quick Shot | -0.15 ranged cooldown, minimum 0.15 |
| Iron Skin | +15% damage reduction |
| Regeneration | Heal 5 HP every 3 seconds |
| Swift Dodge | -0.4s dodge cooldown, minimum 0.3 |

### 6.3 Power-Up Flow

1. All enemies die.
2. The game pauses.
3. A power-up screen appears with 3 random cards.
4. The player clicks 1 card.
5. The chosen upgrade is written into persistent run state.
6. The next level starts with those upgraded stats.

---

## 7. Level Design and Progression

### 7.1 Arena Layout

- Floor size: 30x30
- Walls: north, south, east, west
- No internal obstacles
- Player spawn: `(-13, 0.5, 0)`

### 7.2 Base Level Item Positions

| Item | Position |
|------|----------|
| Health Potion | `(0, 0.15, -5)` |
| Weapon Upgrade | `(10, 0.15, 5)` |

### 7.3 Enemy Spawn Positions

**Turret positions**

1. `(-10, 0.25, -10)`
2. `(10, 0.25, -10)`
3. `(-10, 0.25, 10)`
4. `(10, 0.25, 10)`
5. `(0, 0.25, -12)`
6. `(0, 0.25, 12)`
7. `(-12, 0.25, 0)`
8. `(12, 0.25, 0)`

**Chaser seed positions**

1. `(-5, 0.5, 0)`
2. `(5, 0.5, 0)`
3. `(0, 0.5, 5)`

Each chaser gets a small random X/Z offset when spawned.

### 7.4 Enemy Counts Per Level

| Enemy | Formula |
|-------|---------|
| Turrets | `min(8, 2 + floor((level - 1) / 2))` |
| Chasers | `3 + (level - 1)` |

Chasers are not capped by a hard maximum in the current implementation.

### 7.5 Stat Scaling Per Level

Let `level_offset = level - 1`.

**Turret scaling**

- Health: `+15 * level_offset`
- Fire interval: `-0.12 * level_offset`, minimum `0.8`
- Projectile speed: `+1.0 * level_offset`
- Projectile damage: `+2 * level_offset`
- Rotation speed: `+0.1 * level_offset`
- Detection range: `+0.6 * level_offset`, capped at `+8.0`

**Chaser scaling**

- Health: `+12 * level_offset`
- Move speed: `+0.2 * level_offset`
- Contact damage: `+2 * level_offset`
- Detection range: `+0.5 * level_offset`, capped at `+5.5`

---

## 8. User Interface

### 8.1 HUD

| Element | Behavior |
|---------|----------|
| Health Bar | Top-left, tracks current and max HP |
| Health Text | Displays `HP: current/max` |
| Dodge Bar | Shows dodge readiness/cooldown |
| Score | Top-right |
| Level | Below score |
| Crosshair | Texture-based cursor that follows the mouse |

### 8.2 Game Over Screen

| Element | Current Behavior |
|---------|------------------|
| Background | Full-screen black overlay |
| Title | `YOU DIED` |
| Score | Shows final score |
| Prompt | `Press R to Restart` |

### 8.3 Power-Up Selection Screen

| Element | Current Behavior |
|---------|------------------|
| Background | Dark overlay |
| Title | `LEVEL COMPLETE!` |
| Score Line | Shows score and next level |
| Hint Text | `Choose 1 permanent upgrade` |
| Cards | 3 clickable power-up cards |
| Input Mode | Mouse shown while selecting |
| Game State | Tree paused until a card is selected |

---

## 9. Technical Specifications

### 9.1 Main Scene Structure

```
Main (Node3D)
|-- Environment (Node3D)
|   |-- WorldEnvironment
|   |-- DirectionalLight
|   |-- AmbientLight
|   |-- Floor
|   `-- Walls
|-- Camera3D
|-- Player               [spawned at runtime]
|-- Turrets              [runtime container]
|-- Chasers              [runtime container]
|-- Items                [runtime container]
|-- Projectiles          [runtime container]
|-- UI                   [spawned at runtime]
`-- PowerUpScreen        [spawned at runtime when needed]
```

### 9.2 Script Architecture

| Script | Inherits | Responsibility |
|--------|----------|----------------|
| `main.gd` | `Node3D` | Run state, spawning, scoring, level transitions, progression |
| `player.gd` | `CharacterBody3D` | Movement, aiming, melee, ranged attack, dodge, health |
| `turret.gd` | `Node3D` | Targeting and firing |
| `chaser.gd` | `CharacterBody3D` | Chase behavior, overlap damage, knockback reception |
| `projectile.gd` | `Area3D` | Movement, hit detection, damage |
| `item.gd` | `Area3D` | Pickup detection and item effects |
| `ui.gd` | `CanvasLayer` | HUD and game over display |
| `crosshair.gd` | `TextureRect` | Crosshair cursor behavior |
| `powerup_screen.gd` | `Control` | Power-up selection overlay |
| `powerup_card.gd` | `Control` | Individual power-up card |

### 9.3 Input Map

| Action | Input |
|--------|-------|
| `move_forward` | `W` |
| `move_backward` | `S` |
| `move_left` | `A` |
| `move_right` | `D` |
| `dodge` | `Space` |
| `melee_attack` | Left Mouse Button |
| `ranged_attack` | Right Mouse Button |
| `restart` | `R` |

### 9.4 File Structure

```
simple-rougue-like/
|-- project.godot
|-- GDD.md
|-- scenes/
|   |-- main.tscn
|   |-- player.tscn
|   |-- turret.tscn
|   |-- chaser.tscn
|   |-- projectile.tscn
|   |-- item.tscn
|   |-- ui.tscn
|   |-- powerup_screen.tscn
|   `-- powerup_card.tscn
|-- scripts/
|   |-- main.gd
|   |-- player.gd
|   |-- turret.gd
|   |-- chaser.gd
|   |-- projectile.gd
|   |-- item.gd
|   |-- ui.gd
|   |-- crosshair.gd
|   |-- powerup_screen.gd
|   `-- powerup_card.gd
`-- textures/
	`-- Crosshair.png
```

---

## 10. Game Flow

```
[START RUN]
	|
	v
[SPAWN LEVEL]
	|
	v
[PLAY]
	|- Move, aim, dodge, melee, ranged attack
	|- Enemies activate and attack
	|- Projectiles resolve hits
	|- Items can be collected
	`- Score updates from kills
	|
	v
[CHECK END CONDITION]
	|
	|- If player dies:
	|    |- Freeze player/enemy action
	|    |- Show game over
	|    `- Wait for restart
	|
	`- If all enemies die:
		 |- Cache current run state
		 |- Pause game
		 |- Show 3 power-up choices
		 |- Apply selected power-up
		 `- Spawn next level
```

---

## 11. Future Considerations

| Feature | Notes |
|---------|-------|
| More enemy archetypes | Heavy units, ranged chasers, support enemies |
| More arena variation | Obstacles, alternate layouts, hazards |
| Better feedback | Hit flashes, particles, sound, impact cues |
| Boss or milestone waves | Periodic difficulty spikes |
| Meta progression | Unlocks or long-term progression between runs |
| Save/load | Persist settings and longer-form progress |

---

## 12. Review Checklist

> **Status:** Updated to match current implementation as of May 2026

| # | Question | Current Answer |
|---|----------|----------------|
| 1 | Camera behavior | Static perspective camera |
| 2 | Scoring | Kill score only |
| 3 | Power-ups | 1 of 3 after each cleared level |
| 4 | Player persistence | Upgrades carry across levels during a run |
| 5 | Dodge | Spacebar, invulnerable while active |
| 6 | Melee | Immediate hit with visible swing and knockback |
| 7 | Enemy scaling | Counts and stats scale by level |
| 8 | Restart | Press `R` after death |

### Implementation Readiness Checklist

- [x] GDD reflects current codebase behavior
- [x] Current scoring model documented
- [x] Current level-scaling model documented
- [x] Current power-up flow documented

---

*Version 1.3 updates from 1.2:*

- Removed passive survival scoring from the design.
- Updated the camera section to match the current static camera.
- Updated technical structure to use `powerup_screen.gd` and `powerup_card.gd`.
- Documented current melee swing and knockback behavior.
- Documented current projectile handling and muzzle-based ranged attacks.
- Documented current enemy scaling formulas and spawn-count formulas.
- Updated level progression to reflect the current 8-turret layout and uncapped chaser growth.
