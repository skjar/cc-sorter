-- parser.lua
-- Map/filter parsing and validation
--
-- Symbols:
-- # = wall
-- . = walkway
-- @ = linked chest
-- A-Z = chest anchor point
-- 0 = home
-- * = input access point

local parser = {}

local SPECIAL_HOME = "0"
local SPECIAL_INPUT = "*"

local function isUpperLetter(ch)
  return type(ch) == "string" and ch:match("^[A-Z]$") ~= nil
end

local function isChestChar(ch)
  return ch == "@" or isUpperLetter(ch)
end

local function isSpecialWalkable(ch)
  return ch == SPECIAL_HOME or ch == SPECIAL_INPUT
end

local function splitKey(key)
  local base, dx, dy, dz = key:match("^([A-Z])%[(-?%d+),(-?%d+),(-?%d+)%]$")
  if base then return base, tonumber(dx), tonumber(dy), tonumber(dz) end

  base, dx, dz = key:match("^([A-Z])%[(-?%d+),(-?%d+)%]$")
  if base then return base, tonumber(dx), 0, tonumber(dz) end

  if key:match("^[A-Z]$") then return key, 0, 0, 0 end
  return nil, nil, nil, nil
end

function parser.tileAt(world, x, y, z)
  local rows = world.maps[y]
  if not rows then return "#" end
  local row = rows[z]
  if not row then return "#" end
  if x < 1 or x > #row then return "#" end
  return row:sub(x, x)
end

function parser.isWalkable(world, x, y, z)
  local ch = parser.tileAt(world, x, y, z)
  return ch == "." or isSpecialWalkable(ch)
end

function parser.isChest(world, x, y, z)
  return isChestChar(parser.tileAt(world, x, y, z))
end

local function addSpecial(world, name, pos)
  world.special[name] = world.special[name] or {}
  table.insert(world.special[name], pos)
end

function parser.buildWorld(config)
  local world = {
    maps = config.maps,
    points = {},
    homes = {},
    inputs = {},
    special = {},
    warnings = {},
  }

  for y, rows in pairs(config.maps) do
    for z = 1, #rows do
      local row = rows[z]
      for x = 1, #row do
        local ch = row:sub(x, x)

        if isUpperLetter(ch) then
          if world.points[ch] then error("duplicate anchor point: " .. ch) end
          world.points[ch] = { x = x, y = y, z = z }
        elseif ch == SPECIAL_HOME then
          local p = { x = x, y = y, z = z, symbol = ch }
          table.insert(world.homes, p)
          addSpecial(world, ch, p)
        elseif ch == SPECIAL_INPUT then
          local p = { x = x, y = y, z = z, symbol = ch }
          table.insert(world.inputs, p)
          addSpecial(world, ch, p)
        end
      end
    end
  end

  if #world.homes ~= 1 then
    error("home symbol 0 must appear exactly once across all floors. current: " .. tostring(#world.homes))
  end

  if config.input and config.input.point == SPECIAL_INPUT and #world.inputs == 0 then
    error("input.point='*' but no * exists on the map.")
  end

  return world
end

function parser.getSpecialPoint(world, symbol)
  local list = world.special[symbol]
  if not list or #list == 0 then return nil end
  return list[1]
end

function parser.resolveChestKey(world, key)
  local base, dx, dy, dz = splitKey(key)
  if not base then error("invalid filter key format: " .. tostring(key)) end

  local p = world.points[base]
  if not p then error("missing anchor point: " .. base .. " in " .. tostring(key)) end

  local pos = { x = p.x + dx, y = p.y + dy, z = p.z + dz, key = key }

  if not parser.isChest(world, pos.x, pos.y, pos.z) then
    error("filter " .. key .. " does not resolve to a chest: x="
      .. pos.x .. " y=" .. pos.y .. " z=" .. pos.z
      .. " tile=" .. parser.tileAt(world, pos.x, pos.y, pos.z))
  end

  return pos
end

local accessCandidates = {
  north = { dx = 0,  dz = -1, facing = 2 },
  east  = { dx = 1,  dz = 0,  facing = 3 },
  south = { dx = 0,  dz = 1,  facing = 0 },
  west  = { dx = -1, dz = 0,  facing = 1 },
}

local accessOrder = { "north", "east", "south", "west" }

local function buildAccess(chestPos, sideName, candidate)
  return {
    x = chestPos.x + candidate.dx,
    y = chestPos.y,
    z = chestPos.z + candidate.dz,
    facing = candidate.facing,
    from = sideName,
  }
end

function parser.findAdjacentWalkable(world, chestPos, fromSide)
  if fromSide then
    local candidate = accessCandidates[fromSide]
    if not candidate then
      error("invalid access side for chest " .. tostring(chestPos.key) .. ": " .. tostring(fromSide))
    end

    local access = buildAccess(chestPos, fromSide, candidate)
    if parser.isWalkable(world, access.x, access.y, access.z) then
      return access
    end

    error("configured access side is not walkable for chest "
      .. tostring(chestPos.key)
      .. ": from=" .. tostring(fromSide)
      .. " x=" .. access.x .. " y=" .. access.y .. " z=" .. access.z
      .. " tile=" .. parser.tileAt(world, access.x, access.y, access.z))
  end

  local candidates = {
    accessCandidates.north, -- stand north of chest, face south
    accessCandidates.east,  -- stand east of chest, face west
    accessCandidates.south, -- stand south of chest, face north
    accessCandidates.west,  -- stand west of chest, face east
  }

  for i, c in ipairs(candidates) do
    local access = buildAccess(chestPos, accessOrder[i], c)
    if parser.isWalkable(world, access.x, access.y, access.z) then
      return access
    end
  end

  error("no adjacent walkway for chest " .. tostring(chestPos.key))
end

function parser.prepareFilters(config, world)
  local filters = {}
  local fallbacks = {}

  for key, f in pairs(config.filters) do
    local chest = parser.resolveChestKey(world, key)
    local access = parser.findAdjacentWalkable(world, chest, f.from)

    local entry = {
      key = key,
      label = f.label or key,
      side = f.side or "front",
      from = f.from,
      items = f.items or {},
      tags = f.tags or {},
      pattern = f.pattern,
      patterns = f.patterns or {},
      mods = f.mods or {},
      fallback = f.fallback == true,
      chest = chest,
      access = access,
    }

    table.insert(filters, entry)
    if entry.fallback then table.insert(fallbacks, entry) end
  end

  if #fallbacks == 0 then error("at least one filter must have fallback=true.") end

  return filters, fallbacks
end

function parser.validate(config)
  local world = parser.buildWorld(config)
  local filters, fallbacks = parser.prepareFilters(config, world)

  local registered = {}
  for _, f in ipairs(filters) do
    registered[f.chest.y .. ":" .. f.chest.x .. ":" .. f.chest.z] = true
  end

  for y, rows in pairs(config.maps) do
    for z = 1, #rows do
      for x = 1, #rows[z] do
        local ch = rows[z]:sub(x, x)
        if isChestChar(ch) then
          local k = y .. ":" .. x .. ":" .. z
          if not registered[k] then
            table.insert(world.warnings, "unregistered chest: x=" .. x .. " y=" .. y .. " z=" .. z .. " tile=" .. ch)
          end
        end
      end
    end
  end

  return world, filters, fallbacks
end

return parser
