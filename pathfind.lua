-- pathfind.lua
-- BFS pathfinding. Vertical movement is only allowed through ^ cells.
-- blocked["x,y,z"] = true treats that cell as a temporary wall.

local pathfind = {}

local function key(x, y, z)
  return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
end

function pathfind.key(x, y, z)
  return key(x, y, z)
end

local function isBlocked(blocked, x, y, z)
  return blocked and blocked[key(x, y, z)] == true
end

function pathfind.find(world, parser, start, goal, blocked)
  if start.x == goal.x and start.y == goal.y and start.z == goal.z then
    return {}
  end

  if isBlocked(blocked, goal.x, goal.y, goal.z) then
    return nil, "goal is temporarily blocked"
  end

  local queue = { { x = start.x, y = start.y, z = start.z } }
  local head = 1
  local seen = { [key(start.x, start.y, start.z)] = true }
  local prev = {}

  while head <= #queue do
    local cur = queue[head]
    head = head + 1

    local neighbors = {
      { x = cur.x + 1, y = cur.y, z = cur.z, move = "east" },
      { x = cur.x - 1, y = cur.y, z = cur.z, move = "west" },
      { x = cur.x, y = cur.y, z = cur.z + 1, move = "south" },
      { x = cur.x, y = cur.y, z = cur.z - 1, move = "north" },
    }

    if parser.isStair(world, cur.x, cur.y, cur.z) then
      table.insert(neighbors, { x = cur.x, y = cur.y + 1, z = cur.z, move = "up" })
      table.insert(neighbors, { x = cur.x, y = cur.y - 1, z = cur.z, move = "down" })
    end

    for _, n in ipairs(neighbors) do
      local canEnter
      if n.move == "up" or n.move == "down" then
        canEnter = parser.isStair(world, n.x, n.y, n.z)
      else
        canEnter = parser.isWalkable(world, n.x, n.y, n.z)
      end

      if canEnter and not isBlocked(blocked, n.x, n.y, n.z) then
        local nk = key(n.x, n.y, n.z)
        if not seen[nk] then
          seen[nk] = true
          prev[nk] = { from = key(cur.x, cur.y, cur.z), move = n.move }

          if n.x == goal.x and n.y == goal.y and n.z == goal.z then
            local path = {}
            local ck = nk
            while prev[ck] do
              table.insert(path, 1, prev[ck].move)
              ck = prev[ck].from
            end
            return path
          end

          table.insert(queue, { x = n.x, y = n.y, z = n.z })
        end
      end
    end
  end

  return nil, "path not found"
end

return pathfind
