-- pathfind.lua
-- BFS pathfinding. Vertical movement is allowed between matching walkable cells.
-- blocked cells treat that cell as a temporary wall.
-- blocked edges treat movement between two adjacent cells as temporarily blocked.

local pathfind = {}

local function key(x, y, z)
  return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
end

local function edgeKey(ax, ay, az, bx, by, bz)
  local a = key(ax, ay, az)
  local b = key(bx, by, bz)
  if a < b then return a .. "|" .. b end
  return b .. "|" .. a
end

function pathfind.key(x, y, z)
  return key(x, y, z)
end

function pathfind.edgeKey(ax, ay, az, bx, by, bz)
  return edgeKey(ax, ay, az, bx, by, bz)
end

local function isBlocked(blocked, x, y, z)
  if not blocked then return false end

  local k = key(x, y, z)
  return blocked[k] == true
    or (blocked.cells and blocked.cells[k] == true)
end

local function isEdgeBlocked(blocked, ax, ay, az, bx, by, bz)
  if not blocked or not blocked.edges then return false end
  return blocked.edges[edgeKey(ax, ay, az, bx, by, bz)] == true
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

    if parser.isWalkable(world, cur.x, cur.y, cur.z) then
      table.insert(neighbors, { x = cur.x, y = cur.y + 1, z = cur.z, move = "up" })
      table.insert(neighbors, { x = cur.x, y = cur.y - 1, z = cur.z, move = "down" })
    end

    for _, n in ipairs(neighbors) do
      local canEnter = parser.isWalkable(world, n.x, n.y, n.z)

      if canEnter
        and not isBlocked(blocked, n.x, n.y, n.z)
        and not isEdgeBlocked(blocked, cur.x, cur.y, cur.z, n.x, n.y, n.z)
      then
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
