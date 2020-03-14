local robot = require("robot")
local sides = require("sides")
local m = {}

-- CONSTANTS --
local max_retries = 100
m.dir2sides = {
  [0] = sides.front,
  [1] = sides.right,
  [2] = sides.back,
  [3] = sides.left,
}
m.sides2dir = {
  [sides.front] = 0,
  [sides.right] = 1,
  [sides.back] = 2,
  [sides.left] = 3,
}
-- {north,east,south,west}
local dirs = {
  [0] = {x=0, y=0, z=-1},
  [1] = {x=1, y=0, z=0},
  [2] = {x=0, y=0, z=1},
  [3] = {x=-1, y=0, z=0},
}
local turns = {
  [-3] = function() return robot.turnRight(); end,
  [-2] = function() return robot.turnAround(); end,
  [-1] = function() return robot.turnLeft(); end,
  [0] = function() return true; end,
  [1] = function() return robot.turnRight(); end,
  [2] = function() return robot.turnAround(); end,
  [3] = function() return robot.turnLeft(); end,
}
local _mv_moves = {
  [1] = function() return robot.forward(); end,
  [0] = function() return true; end,
  [-1] = function() return robot.back(); end,
}
local _mh_moves = {
  [1] = function() return robot.up(); end,
  [0] = function() return true; end,
  [-1] = function() return robot.down(); end,
}

-- STATE --
local x, y, z, dir, checkpoints = 0, 0, 0, 0, {}

-- TURNS (only errors) --
function m.turnTo(ndir)
  m.turn(ndir - dir)
end

function m.turn(ddir)
  if turns[ddir]() then dir = (dir + ddir) % 4; else error() end
end

function m.t(ddir) if ddir == nil then ddir = 1; end; m.turn(ddir); end
function m.tt(ndir) if ndir == nil then ndir = 0; end; m.turnTo(ndir); end

-- MOVES --
function m._mv(dv)
  local r,e = _mv_moves[dv]()
  if r then
    local d = dirs[dir]
    x, z = x + dv*d.x, z + dv*d.z
    return true
  else
    return r, e
  end
end

function m._mh(dh)
  local r,e = _mh_moves[dh]()
  if r then
    y = y + dh
    return true
  else
    return r, e
  end
end

function m._mvf(dv)
  local r,e = m._mv(dv)
  if r then return true; end
  if e ~= "entity" then return r, e; end

  for _try = 1, max_retries do
    if dv < 0 then m.turn(2); end
    r,e = robot.swing()
	if dv < 0 then m.turn(2); end
    if r or e == "air" then
	  r,e = m._mv(dv)
	  if r then return true end
	else return r,e; end
  end 

  return false, "too many retries"
end

function m._mhf(dh)
  local r,e = m._mh(dh)
  if r then return true; end
  if e ~= "entity" then return r, e; end

  for _try = 1, max_retries do
    if dh > 0 then r,e = robot.swingUp(); else r,e = robot.swingDown(); end
    if r or e == "air" then
	  r,e = m._mh(dh)
	  if r then return true end
	else return r,e; end
  end 

  return false, "too many retries"
end

function m._rep_move(n, _move)
  local r,e
  local dn = 1
  if n == nil then n = 1; end
  if n < 0 then dn = -1; end
  for i = 1, math.abs(n) do
    r,e = _move(dn)
	if not r then return r,e; end
  end
  return true
end 

function m.mv(dv) return m._rep_move(dv, m._mv); end 
function m.mh(dh) return m._rep_move(dh, m._mh); end 
function m.mvf(dv) return m._rep_move(dv, m._mvf); end 
function m.mhf(dh) return m._rep_move(dh, m._mhf); end

function m.moveTo(nx, ny, nz)
  if ny == nil and nz == nil then nx, ny, nz = nx.x, nx.y, nx.z end
  local r, e
  local bad_x, bad_y, bad_z = false, false, false
  while true do
	if nx == x and ny == y and nz == z then return true; end
	if not bad_z and nz ~= z then
	  if nz - z > 0 then m.turnTo(2); else m.turnTo(0); end
	  local was_z = z
	  r,e = m.mvf(math.abs(nz - z))
	  if was_z ~= z then bad_x, bad_y, bad_z = false, false, false; end
	  if not r then bad_z = true; end
	elseif not bad_x and nx ~= x then
	  if nx - x > 0 then m.turnTo(1); else m.turnTo(3); end
	  local was_x = x
	  r,e = m.mvf(math.abs(nx - x))
	  if was_x ~= x then bad_x, bad_y, bad_z = false, false, false; end
	  if not r then bad_x = true; end
	elseif not bad_y and ny ~= y then
	  local was_y = y
	  r,e = m.mhf(ny - y)
	  if was_y ~= y then bad_x, bad_y, bad_z = false, false, false; end
	  if not r then bad_y = true; end
	else
	  return false, "can't find way"
	end
  end
end

function m.move(dx, dy, dz) return m.moveTo(x + dx, y + dy, z + dz); end
function m.getPos() return x, y, z; end
function m.gpt() return {x:x, y:y, z:z}; end
function m.getDir() return dir; end
function m.getDirVec() local d = dirs[dir]; return d.x, d.y, d.z; end
function m.setPos(nx, ny, nz) x, y, z = nx, ny, nz; end
function m.setDir(ndir) dir = ndir; end
function m.reset() x, y, z, dir, checkpoints = 0, 0, 0, 0, {}; end

-- CHECKPOINTS --
function m.saveCheckpoint() table.insert(checkpoints, {x: x, y:y, z:z, dir:dir}); end

function m.moveToCheckpoint(nx, ny, nz)
  if ny == nil and nz == nil then nx, ny, nz = nx.x, nx.y, nx.z end
  local r,e = m.moveTo(nx, ny, nz)
  if r then m.saveCheckpoint(); end
  return r,e
end

function m.returnBack()
  local to = {x:0, y:0, z:0, dir:0}
  if #checkpoints > 0 then to = table.remove(checkpoints); end
  local r,e = m.moveTo(to)
  if r then m.turnTo(to.dir); end
  return r,e
end

function m.home()
  while x~=0 or y~=0 or z~=0 or dir~=0 do
    local r,e = m.returnBack()
	if not r then return r,e; end
  end
  return true
end

-- MISC --
function m.runUntilEnter(f) while not keyboard.isKeyDown(keyboard.keys.enter) do f(); end; end
function m.time() return os.time() * 1000 / 60 / 60 / 20; end
function m.printTime(t) 
  if t == nil then t = m.time(); end
  local h = math.floor(t / 3600)
  local m = math.floor((t - h * 60) / 60))
  local s = t - h * 3600 - m * 60
  return string.format("%03d:%02d:%02d", h, m, s)
end
function m.printTableKeys(tab) for k,v in pairs(tab) do io.write(k..", "); end; print(); end
function m.printTableValues(tab) for k,v in pairs(tab) do io.write(v..", "); end; print(); end
function m.printTable(tab) for k,v in pairs(tab) do print(k.."="..v); end; end

return m
