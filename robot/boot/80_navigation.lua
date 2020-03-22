local component = require("component")
local sides = require("sides")
local event = require("event")
local m = component.robot
local _x,_y,_z,_d,_s = 0, 0, 0, 0, m.select()
m.maxRetries, m.waitTimeout, m.doSwing = 120, 1, true

local robotMove, robotTurn, robotSelect = m.move, m.turn, m.select

m._dir2move = {
  [0] = {x=0, y=0, z=-1},
  [1] = {x=1, y=0, z=0},
  [2] = {x=0, y=0, z=1},
  [3] = {x=-1, y=0, z=0},
  [4] = {x=0, y=-1, z=0},
  [5] = {x=0, y=1, z=0},
}

m._sides2dir = {
  [sides.forward] = function() return _d end,
  [sides.right] = function()  return (_d + 1) % 4 end,
  [sides.back] = function()   return (_d + 2) % 4 end,
  [sides.left] = function()   return (_d + 3) % 4 end,
  [sides.down] = function() return 4 end,
  [sides.up] = function() return 5 end,
}

m._side_move2com = {
  [sides.forward] = "f",
  [sides.right] = "r",
  [sides.back] = "b",
  [sides.left] = "l",
  [sides.down] = "d",
  [sides.up] = "u",
}

function m.getDir(side) return m._sides2dir[side or sides.front]() end
function m.getMove(side) return m._dir2move[m.getDir(side)] end
function m.getPos() return {x = _x, y = _y, z = _z} end
function m.getCurDir() return _d end
function m.getState() return {x = _x, y = _y, z = _z, d = _d, s = _s} end
function m.setState(x, y, z, d, s)
  if y == nil then _x, _y, _z, _d, _s = x.x, x.y, x.z, x.d, x.s or _s
  else _x, _y, _z, _d, _s = x, y, z, d, s or _s end
end

function m.move(side)
	local res, err = robotMove(side)
	if not res and err ~= "entity" then
    return res, err
  elseif not res then
    for _ = 1, m.maxRetries do
      local start = os.time()
      if m.doSwing and side ~= sides.back then m.swing(side); end
      local wait = m.waitTimeout - (os.time() - start) / 72
      wait = wait > 0.05 and wait or 0.05
      if event.pull(wait, "interrupted") then
        event.push("interrupted", os.time())
        return res, "interrupted"
      end
      res, err = robotMove(side)
      if res then break elseif err ~= "entity" then return res, err end
    end
  end
  if not res then return res, err, "retry limit exceeded" end
  local move = m._dir2move[m._sides2dir[side]()]
  _x, _y, _z = _x + move.x, _y + move.y, _z + move.z
  event.push("robot", m._side_move2com[side])
	return res
end

function m.turn(isRight)
	local res, err = robotTurn(isRight)
	if not res then error(err) end
  if isRight then _d = (_d + 1) % 4 else _d = (_d + 3) % 4 end
  event.push("robot", isRight and "r" or "l")
	return true
end

function m.select(pos)
  if not pos then return _s end
  if _s == pos then return pos end
  _s = robotSelect(pos)
  event.push("robot", "S".._s)
  return _s
end

function m._select(pos) return robotSelect(pos) end

function m.pipe(fromSide, toSide, count)
  count = count or 1000
  local tankSize = m.tankSpace()
  while count > 0 do
    local delta, res, err = math.min(tankSize, count)
    local outSize = delta
    res, err = m.drain(fromSide, delta)
    if res then
      while m.tankLevel() > 0 do
        outSize = math.min(outSize, m.tankLevel())
        res, err = m.fill(toSide, outSize)
        if not res then outSize = outSize / 2 end
        if outSize < 1000 then 
          outSize = 1000; 
          print("Cannot put fluid", res, err) 
          if event.pull(1, "interrupted") then return res, "interrupted" end
        end
      end
      count = count - delta
    else
      print("Cannot get fluid", res, err)
      if event.pull(1, "interrupted") then return res, "interrupted" end
    end
  end
  return true
end
