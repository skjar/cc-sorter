-- config.lua
-- CC:Tweaked storage sorter turtle configuration
-- facing: 0=north(-z), 1=east(+x), 2=south(+z), 3=west(-x)
--
-- Map symbols:
-- # = wall
-- . = walkway
-- @ = linked chest
-- A-Z = chest anchor point
-- 0 = home / idle position
-- * = input access point

return {
  home_abs = { x = -297, y = 70, z = -306, facing = 1 },

  input = {
    point = nil, -- "*",       -- Input access point. nil means suck at home.
    side = "up",              -- Input chest side: "front" / "up" / "down"
    idle_seconds = 5,
    max_take_per_cycle = 64,
  },

  movement = {
    -- "avoid": treat blocked cells as temporary walls and re-run BFS
    -- "wait" : retry the same movement after waiting
    obstacle_mode = "avoid",

    obstacle_retries = 10,
    obstacle_wait_seconds = 2,
    max_replans = 32,

    save_every_steps = 8,
    state_file = "state.lua",
  },

  fuel = {
    auto_refuel = true,
    slots = { 16 },       -- Reserved fuel slots. Keep fuel items here.
    min_level = 20,       -- Refuel before movement when fuel drops below this.
    target_level = 400,   -- Refuel up to this level when possible.
  },

  maps = {
    [2] = {
      "#####################",
      "#@@#@@#.#####.#@@#@@#",
      "#.......#####.......#",
      "#@@#@@#.#####.#@@#@@#",
      "#.......#####.......#",
      "#@@#@@#.#####.#@@#@@#",
      "#.......#####.......#",
      "#.......#####.......#",
      "#...................#",
      "#...................#",
      "#@@#@@#.......#@@#@@#",
      "#...................#",
      "#@@#@@#.......#@@#@@#",
      "#...................#",
      "#@@#@@#.......#@@#@@#",
      "#####################",
    },
    [1] = {
      "#####################",
      "#@@#F@#.#####.#G@#@@#",
      "#.......#####.......#",
      "#@@#E@#.#####.#H@#@@#",
      "#.......#####.......#",
      "#@@#D@#.#####.#I@#@@#",
      "#.......#####.......#",
      "#.......#####.......#",
      "#...................#",
      "#...................#",
      "#@@#C@#.......#J@#@@#",
      "#...................#",
      "#@@#B@#.......#K@#@@#",
      "#...................#",
      "#@@#A@#0.....Z#L@#@@#",
      "#####################",
    },
  },

  filters = require("filters"),
}
