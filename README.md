# CC:Tweaked Storage Turtle Sorter

## Files

- `config.lua`: configuration
- `filters.lua`: item routing rules
- `parser.lua`: map/filter validation
- `pathfind.lua`: BFS pathfinding
- `move.lua`: GPS sync, coordinate tracking, and movement
- `sort.lua`: main sorter loop
- `startup.lua`: automatic startup
- `inspect_item.lua`: item ID and tag inspection helper

## Map Symbols

```text
# = wall
. = walkway
@ = linked chest
A-Z = chest anchor point
0 = home / idle position
* = input access point
```

Example:

```text
############
#A@@..B@@..#
#..........#
#0.........#
#....*.....#
#C@@..D@@..#
############
```

## Input

Set `input.point` in `config.lua`.

```lua
input = {
  point = "*",
  side = "up",
}
```

With this setting, the turtle moves to `*` and runs `suckUp()` from the chest above it.

Set `point = nil` to suck at home `0`.

## Filters

Item routing rules live in `filters.lua`. Each filter maps an item rule to a chest.

```lua
filters = {
  A = {
    label = "Cobblestone",
    from = "north",
    side = "front",
    items = { "minecraft:cobblestone" },
  },
}
```

`from` controls where the turtle stands relative to the chest:

- `"north"`: stand north of the chest and face south
- `"east"`: stand east of the chest and face west
- `"south"`: stand south of the chest and face north
- `"west"`: stand west of the chest and face east

Omit `from` to auto-pick the first adjacent walkway.

`side` controls the turtle drop side after it reaches the access position. Usually this is `"front"`.

Filter keys can use relative chest positions:

- `A`: the chest marked with anchor `A`
- `A[dx,dz]`: a chest relative to `A` on the same floor
- `A[dx,dy,dz]`: a chest relative to `A`, including floor offset

Example:

```lua
["A[0,1,0]"] = {
  label = "Floor Above A",
  from = "north",
  side = "front",
  items = { "minecraft:stone" },
}
```

Filter rules can contain multiple values:

```lua
B = {
  label = "Ice and Fire / Cataclysm",
  from = "north",
  side = "front",
  mods = { "iceandfire", "cataclysm" },
}
```

Supported rule fields:

- `items = { "minecraft:cobblestone", "minecraft:stone" }`
- `tags = { "minecraft:logs" }`
- `mods = { "iceandfire", "cataclysm" }`
- `patterns = { "^iceandfire:", "^cataclysm:" }`
- `pattern = "^minecraft:.*_log$"` for a single legacy pattern

Rules are checked in this order: `items`, `tags`, `mods`, `patterns`, then `fallback`.

## Installation

Place all `.lua` files on the turtle and run:

```lua
sort
```

Include `startup.lua` if you want the sorter to start automatically on boot.

## Obstacle Avoidance

Set `movement.obstacle_mode = "avoid"` in `config.lua` to treat a blocked forward cell as a temporary wall and re-run BFS.

```lua
movement = {
  obstacle_mode = "avoid",
  max_replans = 32,
}
```

Notes:

- Avoidance only works when another mapped walkway exists.
- Vertical movement is allowed when the same `x,z` cell is walkable on both floors.
- In `"avoid"` mode, blocked vertical moves can be routed around when another mapped path exists.
- For narrow one-way paths, `"wait"` mode may be better than `"avoid"`.

## Fuel

The turtle can refuel automatically from reserved inventory slots.

```lua
fuel = {
  auto_refuel = true,
  slots = { 16 },
  min_level = 20,
  target_level = 400,
}
```

Keep coal, charcoal, lava buckets, or other fuel items in the configured slots. By default, only slot 16 is used so sortable fuel items in other slots are not consumed by accident.

Configured fuel slots are skipped by input pickup and item delivery.

## Assumptions

- The turtle does not dig.
- The default input chest is above `*`.
- Vertical floor changes happen between matching walkable cells on adjacent floors.
- GPS is required at startup.
- If GPS is unavailable or facing calibration fails, the turtle refuses to start.
- `state.lua` is only used as a movement checkpoint after GPS sync succeeds.
