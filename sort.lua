-- sort.lua
-- Main storage sorting loop

local config = require("config")
local parser = require("parser")
local mover = require("move")

local world, filters, fallbacks = parser.validate(config)

for _, w in ipairs(world.warnings) do
  print("WARN: " .. w)
end

mover.init(config, world, parser)

local function isFuelSlot(slot)
  local fuelConfig = config.fuel
  if not fuelConfig or not fuelConfig.slots then return false end

  for _, fuelSlot in ipairs(fuelConfig.slots) do
    if fuelSlot == slot then return true end
  end

  return false
end

local function sideSuck(side, count)
  if side == "up" then return turtle.suckUp(count) end
  if side == "down" then return turtle.suckDown(count) end
  return turtle.suck(count)
end

local function sideDrop(side, count)
  if side == "up" then return turtle.dropUp(count) end
  if side == "down" then return turtle.dropDown(count) end
  return turtle.drop(count)
end

local function findDestination(detail)
  -- Priority: items -> tags -> mods -> patterns -> fallback

  for _, f in ipairs(filters) do
    if f.items then
      for _, item in ipairs(f.items) do
        if detail.name == item then return f end
      end
    end
  end

  for _, f in ipairs(filters) do
    if f.tags and detail.tags then
      for _, tag in ipairs(f.tags) do
        if detail.tags[tag] then return f end
      end
    end
  end

  for _, f in ipairs(filters) do
    if f.mods then
      for _, modId in ipairs(f.mods) do
        if detail.name:sub(1, #modId + 1) == modId .. ":" then return f end
      end
    end
  end

  for _, f in ipairs(filters) do
    if f.pattern and detail.name:match(f.pattern) then return f end
    if f.patterns then
      for _, pattern in ipairs(f.patterns) do
        if detail.name:match(pattern) then return f end
      end
    end
  end

  return fallbacks[1]
end

local function deliver(filter, slot)
  local ok, err = mover.goTo(filter.access.x, filter.access.y, filter.access.z)
  if not ok then return false, err end

  mover.faceAccess(filter.access)
  turtle.select(slot)

  local count = turtle.getItemCount(slot)
  if count == 0 then return true end

  if sideDrop(filter.side, count) then return true end
  return false, "drop failed: " .. (filter.label or filter.key)
end

local function deliverWithFallback(filter, slot)
  local ok, err = deliver(filter, slot)
  if ok then return true end

  print("delivery failed: " .. tostring(err))

  if filter.fallback then return false, err end

  for _, fb in ipairs(fallbacks) do
    print("try fallback: " .. (fb.label or fb.key))
    local fbOk, fbErr = deliver(fb, slot)
    if fbOk then return true end
    print("fallback failed: " .. tostring(fbErr))
  end

  return false, "all destinations failed"
end

local function scanAndDeliver()
  for slot = 1, 16 do
    if not isFuelSlot(slot) then
      local detail = turtle.getItemDetail(slot, true)
      if detail then
        local dest = findDestination(detail)
        print("slot " .. slot .. ": " .. detail.name .. " -> " .. (dest.label or dest.key))

        local ok, err = deliverWithFallback(dest, slot)
        if not ok then
          print("ERROR: " .. tostring(err))
          mover.home()
          return false
        end
      end
    end
  end

  return true
end

local function takeInput()
  local inputPoint = config.input and config.input.point

  if inputPoint then
    local p = parser.getSpecialPoint(world, inputPoint)
    if not p then error("input point not found: " .. tostring(inputPoint)) end

    local ok, err = mover.goTo(p.x, p.y, p.z)
    if not ok then error(err) end
  else
    mover.home()
  end

  local side = (config.input and config.input.side) or "up"
  local maxTake = (config.input and config.input.max_take_per_cycle) or 64

  for slot = 1, 16 do
    if not isFuelSlot(slot) and turtle.getItemCount(slot) == 0 then
      turtle.select(slot)
      if sideSuck(side, maxTake) then
        return true
      end
    end
  end

  return false
end

print("storage turtle sorter started")

while true do
  local ok, err = pcall(function()
    if takeInput() then
      scanAndDeliver()
      mover.home()
    else
      sleep((config.input and config.input.idle_seconds) or 5)
    end
  end)

  if not ok then
    if tostring(err) == "Terminated" then
      print("terminated")
      break
    end

    print("FATAL: " .. tostring(err))
    pcall(function() mover.home() end)
    sleep(10)
  end
end
