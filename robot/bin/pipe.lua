local r = require("component").robot
local sides = require("sides")
local fromS, toS, count = ...

if r.tankCount() == 0 or r.tankLevel() > 0 or not fromS or not toS or not count then
  print("Usage: pipe fromSide toSide count")
  print("Must have 'Tank Upgrade'")
  print("Selected tank must be empty")
  print(r.tankCount(), r.tankLevel(), fromS, toS, count)
  os.exit(1)
end

fromS, toS, count = sides[fromS], sides[toS], tonumber(count)
local time = os.time()
print(r.pipe(fromS, toS, count))
print("Done:", (os.time() - time) / 72)
