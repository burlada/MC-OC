local component = require("component")
local sides = require("sides")
local event = require("event")
local misc = require("misc")
local exec = misc.preq("exec")
local r = component.robot
local _turns = {
  [0] = function() end,
  [1] = function() r.turn(true) end,
  [2] = function() r.turn(true); r.turn(true); end,
  [3] = function() r.turn(false) end,
}
local m = {}
m.inv = pcall(function() return component.inventory_controller end)
m.geo = pcall(function() return component.geolyzer end)

function m.mf(cnt)
  local side = cnt > 0 and sides.front or sides.back
  for _ = 1, math.abs(cnt) do
    local res, err, sig = r.move(side)
    if not res then return res, err, sig end
  end
  return true
end
function m.mu(cnt)
  local side = cnt > 0 and sides.up or sides.down
  for _ = 1, math.abs(cnt) do
    local res, err, sig = r.move(side)
    if not res then return res, err, sig end
  end
  return true
end
m.my = m.mu
function m.mb(cnt) cnt = cnt or 1; return m.mf(-cnt) end
function m.md(cnt) cnt = cnt or 1; return m.mu(-cnt) end
function m.tr(cnt) _turns[ (cnt or 1) % 4]() return true; end
function m.tl(cnt) _turns[-(cnt or 1) % 4]() return true; end
function m.ta() r.turn(true); r.turn(true); return true; end
function m.tt(ndir) return m.tr(ndir - r.getCurDir()) end
function m._mxp1() m.tt(1) return r.move(sides.front) end
function m._mxm1() m.tt(3) return r.move(sides.front) end
function m._mzp1() m.tt(2) return r.move(sides.front) end
function m._mzm1() m.tt(0) return r.move(sides.front) end

function m.mx(cnt)
  cnt = cnt or 1; if cnt == 0 then return true end
  if cnt > 0 then m.tt(1) else m.tt(3) end
  return m.mf(math.abs(cnt))
end
function m.mz(cnt)
  cnt = cnt or 1; if cnt == 0 then return true end
  if cnt > 0 then m.tt(2) else m.tt(0) end
  return m.mf(math.abs(cnt))
end
function m.Sel(slot) return r.select(slot) end
function m.Pf() return r.place(sides.front) end
function m.Pu() return r.place(sides.up) end
function m.Pd() return r.place(sides.down) end
function m.Df() return r.swing(sides.front) end
function m.Du() return r.swing(sides.up) end
function m.Dd() return r.swing(sides.down) end

m.commands = misc.tWrap({
  f = {func=function() r.move(sides.front) end, undo=function() r.move(sides.back) end},
  b = {func=function() r.move(sides.back) end, undo=function() r.move(sides.front) end},
  r = {func=function() r.turn(sides.right) end, undo=function() r.turn(sides.left) end},
  l = {func=function() r.turn(sides.left) end, undo=function() r.turn(sides.right) end},
  a = {func=m.ta, undo=m.ta},
  x = {func=m._mxp1, undo=m._mxm1},
  z = {func=m._mzp1, undo=m._mzm1},
})

function m.play(say, otherCommands)
  return exec.exec(exec.parse(say, m.commands + (otherCommands or {})))
end

return m
