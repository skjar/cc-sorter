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
  A = {
    label = "Ingot",
    from = "north",
    side = "front",
    tags = {
      "c:ingots",
    },
  },

  B = {
    label = "Gem",
    from = "north",
    side = "front",
    tags = {
      "c:gems",
    },
  },

  ["C[0,1,0]"] = {
    label = "Log",
    from = "north",
    side = "front",
    tags = {
      "minecraft:logs",
    },
  },

  C = {
    label = "Wood",
    from = "north",
    side = "front",
    items = {
      "minecraft:stick",
    },
    tags = {
      "minecraft:planks",
      "minecraft:wooden_stairs",
      "minecraft:wooden_slabs",
      "minecraft:wooden_fences",
      "minecraft:fence_gates",
      "minecraft:wooden_doors",
      "minecraft:wooden_trapdoors",
      "minecraft:wooden_pressure_plates",
      "minecraft:wooden_buttons",
      "minecraft:saplings",
      "c:rods/wooden",
    },
  },

  ["K[0,1,0]"] = {
    label = "Honey",
    from = "north",
    side = "front",
    items = {
      "minecraft:honeycomb",
      "minecraft:honey_bottle",
      "minecraft:honeycomb_block",
      "minecraft:honey_block",
      "minecraft:bee_nest",
      "minecraft:beehive",
    },
    mods = {
      "productivebees",
      "productivelib",
      "the_bumblezone",
    },
  },

  K = {
    label = "Evilcraft",
    from = "north",
    side = "front",
    mods = {
      "evilcraft",
    },
  },

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
