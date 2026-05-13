-- move.lua
-- Movement and GPS sync with internal coordinate tracking.
-- With obstacle_mode="avoid", blocked cells are treated as temporary walls.

local pathfind = require("pathfind")

local move = {}

local configRef
local worldRef
local parserRef
local stateFile = "state.lua"

local state = {
  x = 1,
  y = 1,
  z = 1,
  facing = 0,
  saveCounter = 0,
}

local delta = {
  [0] = { x = 0, z = -1 },
  [1] = { x = 1, z = 0 },
  [2] = { x = 0, z = 1 },
  [3] = { x = -1, z = 0 },
}

local dirByName = { north = 0, east = 1, south = 2, west = 3 }
local stepDir = { north = 0, east = 1, south = 2, west = 3 }

local function fuelLevel()
  return turtle.getFuelLevel()
end

local function autoRefuel(required)
  local fuelConfig = configRef and configRef.fuel
  if not fuelConfig or fuelConfig.auto_refuel ~= true then return false end

  local level = fuelLevel()
  if level == "unlimited" then return true end
  if type(level) ~= "number" then return false end

  local slots = fuelConfig.slots or { 16 }
  local target = fuelConfig.target_level or math.max(required, fuelConfig.min_level or required)
  local selected = turtle.getSelectedSlot()

  for _, slot in ipairs(slots) do
    if level >= target then break end
    if turtle.getItemCount(slot) > 0 then
      turtle.select(slot)

      while level < target and turtle.getItemCount(slot) > 0 do
        if not turtle.refuel(1) then break end
        level = fuelLevel()
        if level == "unlimited" then
          turtle.select(selected)
          return true
        end
      end
    end
  end

  turtle.select(selected)
  return type(level) == "number" and level >= required
end

local function checkFuel(required, context)
  local level = fuelLevel()
  if level == "unlimited" then return true end
  if type(level) ~= "number" then return true end

  local fuelConfig = configRef and configRef.fuel
  local minLevel = fuelConfig and fuelConfig.min_level or required
  local needed = math.max(required, minLevel)
  if level >= needed then return true end

  if autoRefuel(needed) then return true end

  level = fuelLevel()
  if level == "unlimited" then return true end
  if type(level) ~= "number" then return true end
  if level >= needed then return true end

  return false, "not enough fuel for " .. context
    .. ": level=" .. level
    .. " required=" .. required
    .. " min_level=" .. minLevel
end

local function saveState(force)
  local every = (configRef.movement and configRef.movement.save_every_steps) or 8

  state.saveCounter = state.saveCounter + 1
  if not force and state.saveCounter < every then return end
  state.saveCounter = 0

  local f = fs.open(stateFile, "w")
  f.write("return {")
  f.write("x=" .. state.x .. ",")
  f.write("y=" .. state.y .. ",")
  f.write("z=" .. state.z .. ",")
  f.write("facing=" .. state.facing)
  f.write("}")
  f.close()
end

local function loadState()
  if not fs.exists(stateFile) then return false end

  local ok, loaded = pcall(dofile, stateFile)
  if not ok or type(loaded) ~= "table" then return false end

  state.x = loaded.x or state.x
  state.y = loaded.y or state.y
  state.z = loaded.z or state.z
  state.facing = loaded.facing or state.facing
  return true
end

local function waitMove(fn, label)
  local fuelOk, fuelErr = checkFuel(1, label)
  if not fuelOk then return false, fuelErr end

  local retries = (configRef.movement and configRef.movement.obstacle_retries) or 10
  local waitSec = (configRef.movement and configRef.movement.obstacle_wait_seconds) or 2

  for i = 1, retries do
    if fn() then return true end
    print("blocked: " .. label .. " " .. i .. "/" .. retries)
    sleep(waitSec)
  end

  return false, "movement failed: " .. label
end

function move.pos()
  return { x = state.x, y = state.y, z = state.z, facing = state.facing }
end

function move.face(direction)
  local target = type(direction) == "number" and direction or dirByName[direction]
  if target == nil then error("unknown direction: " .. tostring(direction)) end

  local diff = (target - state.facing) % 4

  if diff == 1 then
    turtle.turnRight()
  elseif diff == 2 then
    turtle.turnRight()
    turtle.turnRight()
  elseif diff == 3 then
    turtle.turnLeft()
  end

  state.facing = target
  saveState(false)
end

function move.forward()
  local ok, err = waitMove(turtle.forward, "forward")
  if not ok then return false, err end

  local d = delta[state.facing]
  state.x = state.x + d.x
  state.z = state.z + d.z
  saveState(false)
  return true
end

function move.tryForwardOnce()
  local fuelOk, fuelErr = checkFuel(1, "forward")
  if not fuelOk then return false, fuelErr end
  if not turtle.forward() then return false end

  local d = delta[state.facing]
  state.x = state.x + d.x
  state.z = state.z + d.z
  saveState(false)
  return true
end

function move.back()
  local ok, err = waitMove(turtle.back, "back")
  if not ok then return false, err end

  local d = delta[state.facing]
  state.x = state.x - d.x
  state.z = state.z - d.z
  saveState(false)
  return true
end

function move.up()
  local ok, err = waitMove(turtle.up, "up")
  if not ok then return false, err end

  state.y = state.y + 1
  saveState(false)
  return true
end

function move.down()
  local ok, err = waitMove(turtle.down, "down")
  if not ok then return false, err end

  state.y = state.y - 1
  saveState(false)
  return true
end

local function targetOfStep(stepName)
  if stepName == "north" then return state.x, state.y, state.z - 1 end
  if stepName == "east"  then return state.x + 1, state.y, state.z end
  if stepName == "south" then return state.x, state.y, state.z + 1 end
  if stepName == "west"  then return state.x - 1, state.y, state.z end
  if stepName == "up"    then return state.x, state.y + 1, state.z end
  if stepName == "down"  then return state.x, state.y - 1, state.z end
  return nil, nil, nil
end

local function stepOnce(name)
  if stepDir[name] ~= nil then
    move.face(stepDir[name])
    return move.tryForwardOnce()
  end
  if name == "up" then
    local fuelOk, fuelErr = checkFuel(1, "up")
    if not fuelOk then return false, fuelErr end
    return turtle.up()
  end
  if name == "down" then
    local fuelOk, fuelErr = checkFuel(1, "down")
    if not fuelOk then return false, fuelErr end
    return turtle.down()
  end
  return false
end

local function applySuccessfulVertical(name)
  if name == "up" then
    state.y = state.y + 1
  elseif name == "down" then
    state.y = state.y - 1
  end
  saveState(false)
end

local function stepWait(name)
  if stepDir[name] ~= nil then
    move.face(stepDir[name])
    return move.forward()
  end
  if name == "up" then return move.up() end
  if name == "down" then return move.down() end
  return false, "unknown step: " .. tostring(name)
end

local function blockFailedStep(blocked, stepName, sx, sy, sz)
  if stepName == "up" or stepName == "down" then
    blocked.edges = blocked.edges or {}
    blocked.edges[pathfind.edgeKey(state.x, state.y, state.z, sx, sy, sz)] = true
    print("avoid blocked move: x=" .. state.x .. " y=" .. state.y .. " z=" .. state.z
      .. " -> x=" .. sx .. " y=" .. sy .. " z=" .. sz)
    return
  end

  blocked.cells = blocked.cells or {}
  blocked.cells[pathfind.key(sx, sy, sz)] = true
  print("avoid blocked cell: x=" .. sx .. " y=" .. sy .. " z=" .. sz)
end

function move.goTo(x, y, z)
  local mode = (configRef.movement and configRef.movement.obstacle_mode) or "avoid"

  if mode ~= "avoid" then
    local path, err = pathfind.find(worldRef, parserRef, state, { x = x, y = y, z = z })
    if not path then return false, err end

    for _, s in ipairs(path) do
      local ok, moveErr = stepWait(s)
      if not ok then return false, moveErr end
    end

    saveState(true)
    return true
  end

  local blocked = {}
  local replans = 0
  local maxReplans = (configRef.movement and configRef.movement.max_replans) or 32

  while not (state.x == x and state.y == y and state.z == z) do
    local path, err = pathfind.find(worldRef, parserRef, state, { x = x, y = y, z = z }, blocked)
    if not path then return false, err end

    local needReplan = false

    for _, s in ipairs(path) do
      local sx, sy, sz = targetOfStep(s)
      local ok, stepErr = stepOnce(s)

      if ok then
        if s == "up" or s == "down" then applySuccessfulVertical(s) end
      else
        if stepErr then return false, stepErr end

        blockFailedStep(blocked, s, sx, sy, sz)
        replans = replans + 1

        if replans > maxReplans then
          return false, "avoid replans exceeded the limit"
        end

        needReplan = true
        break
      end

      if state.x == x and state.y == y and state.z == z then break end
    end

    if not needReplan and not (state.x == x and state.y == y and state.z == z) then
      -- Defensive infinite-loop guard.
      replans = replans + 1
      if replans > maxReplans then return false, "goTo made no progress" end
    end
  end

  saveState(true)
  return true
end

local function closeTo(value, target)
  return math.abs(value - target) < 0.25
end

local function inspectFrontForCalibration()
  local ok, detail = turtle.inspect()
  if ok then
    return false, "front block: " .. tostring(detail and detail.name or "unknown")
  end

  if turtle.detect() then
    return false, "front block detected"
  end

  return true
end

local function calibrateFacing(absX, absY, absZ)
  local fuelOk, fuelErr = checkFuel(2, "facing calibration")
  if not fuelOk then return nil, fuelErr end

  local lastErr = "no adjacent open cell for facing calibration"
  local attempts = {}

  local function recordAttempt(turn, reason)
    attempts[#attempts + 1] = tostring(turn + 1) .. "=" .. reason
    lastErr = "could not move for facing calibration. attempts: " .. table.concat(attempts, ", ")
  end

  for turn = 0, 3 do
    if turn > 0 then turtle.turnRight() end

    local clear, blockErr = inspectFrontForCalibration()
    if not clear then
      recordAttempt(turn, blockErr)
    else
      local moved, moveErr = turtle.forward()
      if moved then
        local nx, ny, nz = gps.locate(5)

        local backOk = false
        local backErr = nil
        for i = 1, 5 do
          local ok, err = turtle.back()
          if ok then
            backOk = true
            break
          end
          backErr = err
          sleep(1)
        end

        if not backOk then
          return nil, "moved for facing calibration but could not return to the start cell: "
            .. tostring(backErr or "blocked")
        end

        if not nx then
          lastErr = "GPS locate failed after facing calibration move"
        else
          local dx = nx - absX
          local dz = nz - absZ

          if closeTo(dx, 1) and closeTo(dz, 0) then return 1 end
          if closeTo(dx, -1) and closeTo(dz, 0) then return 3 end
          if closeTo(dx, 0) and closeTo(dz, 1) then return 2 end
          if closeTo(dx, 0) and closeTo(dz, -1) then return 0 end

          lastErr = "GPS delta is not one block: dx=" .. tostring(dx) .. " dz=" .. tostring(dz)
        end
      else
        recordAttempt(turn, tostring(moveErr or "blocked"))
      end
    end
  end

  turtle.turnRight()
  return nil, lastErr
end

function move.init(config, world, parser)
  configRef = config
  worldRef = world
  parserRef = parser
  stateFile = (config.movement and config.movement.state_file) or "state.lua"

  local ax, ay, az = gps.locate(5)
  if ax then
    local h = world.homes[1]
    local homeAbs = config.home_abs

    state.x = math.floor(ax - homeAbs.x + h.x + 0.5)
    state.y = math.floor(ay - homeAbs.y + h.y + 0.5)
    state.z = math.floor(az - homeAbs.z + h.z + 0.5)

    local facing, err = calibrateFacing(ax, ay, az)
    if not facing then
      error("facing calibration failed: " .. err)
    end
    state.facing = facing

    saveState(true)
    print("GPS synced: x=" .. state.x
      .. " y=" .. state.y
      .. " z=" .. state.z
      .. " facing=" .. state.facing
      .. " facing_source=calibrated")
    return true
  end

  error("GPS unavailable; refusing to start without GPS sync")
end

function move.home()
  local h = worldRef.homes[1]
  return move.goTo(h.x, h.y, h.z)
end

function move.faceAccess(access)
  move.face(access.facing)
end

return move
