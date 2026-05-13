-- filters.lua
-- Item routing rules for the storage sorter.

-- from controls where the turtle stands relative to the chest:
-- "north", "east", "south", or "west". Omit it to auto-pick a side.
--
-- Supported rule fields:
-- keys:
-- A = anchor chest
-- A[dx,dz] = chest relative to A on the same floor
-- A[dx,dy,dz] = chest relative to A, including floor offset
--
-- Rule fields:
-- items = { "minecraft:cobblestone" }
-- tags = { "minecraft:logs" }
-- mods = { "iceandfire", "cataclysm" }
-- patterns = { "^iceandfire:", "^cataclysm:" }
-- pattern = "^minecraft:.*_log$"
-- fallback = true

return {
  L = {
    label = "Cobblestone",
    from = "north",
    side = "front",
    items = {
      "minecraft:cobblestone",
    },
  },

  ["L[3,0]"] = {
    label = "Snowball",
    from = "north",
    side = "front",
    items = {
      "minecraft:snowball",
    },
  },

  -- ["A[0,1,0]"] = {
  --   label = "Same XZ On Floor Above",
  --   from = "north",
  --   side = "front",
  --   items = {
  --     "minecraft:stone",
  --   },
  -- },

  -- B = {
  --   label = "Ice and Fire / Cataclysm",
  --   from = "north",
  --   side = "front",
  --   mods = {
  --     "iceandfire",
  --     "cataclysm",
  --   },
  -- },

  Z = {
    label = "Unsorted",
    from = "west",
    side = "front",
    fallback = true,
  },
}
