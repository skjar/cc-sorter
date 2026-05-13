-- inspect_item.lua
-- Helper script for inspecting item name / tags / nbt in turtle slots.

local function printTags(tags)
  if not tags then
    print("  tags: none")
    return
  end

  print("  tags:")
  local count = 0
  for tag, value in pairs(tags) do
    if value then
      print("    " .. tag)
      count = count + 1
    end
  end

  if count == 0 then print("    none") end
end

for slot = 1, 16 do
  local d = turtle.getItemDetail(slot, true)
  if d then
    print("slot " .. slot)
    print("  name: " .. tostring(d.name))
    print("  displayName: " .. tostring(d.displayName))
    print("  count: " .. tostring(d.count))
    print("  nbt: " .. tostring(d.nbt))
    printTags(d.tags)
  end
end
