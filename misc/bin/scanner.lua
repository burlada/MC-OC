local comp=require("component")
local scan=require("scan")
local event=require("event")
local keys=require("keys")
local term=require("term")
local geo, gpu = comp.geolyzer, comp.gpu
local scrW, scrH = gpu.getResolution()
local keybinds = keys.loadConfig("/etc/scanner.cfg", {
  left = {{"left"}}, right = {{"right"}}, up = {{"up"}}, down = {{"down"}}, pageUp = {{"pageUp"}}, pageDown = {{"pageDown"}},
  scanLvlUp = {{"-"}}, scanLvlDown = {{"+"}}, toggleMode = {{"space"}}, close = {{"control", "c"}}, refresh = {{"r"}},
})
local running, changed, scanMode = true, true, "full"
local bx,by,bz = 1,1,1
local scanW, scanD, scanLvl, scanMaxLvl = 4, 2, 1, 6
local baseX = scanW*8+2
local y,h,x,w,z,d = ...
if not y or not geo or not gpu then
  print("Usage: scanner y h x w z d")
  print("Need geolyzer and screen")
  print(keys.help(keybinds))
  os.exit(0)
end
y, h = tonumber(y or "0"), tonumber(h or "1")
x, z = tonumber(x or "-32"), tonumber(z or "-32")
w, d = tonumber(w or "64"), tonumber(d or "64")

local scanner = scan.init(x,z,y,w,d,h)

gpu.fill(1,1,scrW,scrH," ")
gpu.fill(1+scanW*8,1,1,scrH,"‖")
gpu.fill(1,1+scanD*8,scrW,1,"=")

local exitHandle,keyDownHandle
local function close()
  running=false
  event.cancel(exitHandle)
  event.cancel(keyDownHandle)
  term.clear()
  os.exit(0)
end
local function shift(dx,dz,dy)
  print("Shift", dx,dz,dy)
  bx = math.max(0,math.min(bx+dx, data.bx-scanW+1))
  bz = math.max(0,math.min(bz+dz, data.bz-scanD+1))
  by = math.max(0,math.min(by+dy, data.by))
  changed = true
end
local function toggleMode()
  if scanMode == "full" then scanMode = "window"
  elseif scanMode == "window" then scanMode = "none"
  else scanMode = "full" end
end
local function draw(tick)
  local repr = scanner.getRepr(by,bx,bz,scanW,scanD)
  local scans, sizes = scanner.getScanCnt()
  local cx,cz,cy = scanner.x+(bx-1+scanW/2)*scanner.bw, scanner.z+(bz-1+scanD/2)*scanner.bd, scanner.y+(by-1)*scanner.bh
  for z, line in ipairs(repr) do gpu.set(1, 1+#repr-z, line) end
  gpu.set(baseX,1, " Mode: "..scanMode)
  gpu.set(baseX,2, " Tick: "..tostring(tick))
  gpu.set(baseX,3, " Scan: "..tostring(scans))
  gpu.set(baseX,4, " Lvl: "..tostring(scanLvl).."->"..tostring(sizes[scanLvl]))
  gpu.set(baseX,5, " Bxyz: "..tostring(bx)..tostring(bz)..tostring(by))
  gpu.set(baseX,6, " P: "..tostring(cx).." "..tostring(cz).." "..tostring(cy))
end
local handlers = {
  left = function() shift(-1, 0, 0) end,
  right = function() shift(1, 0, 0) end,
  up = function() shift(0, 1, 0) end,
  down = function() shift(0, -1, 0) end,
  pageUp = function() shift(0, 0, 1) end,
  pageDown = function() shift(0, 0, -1) end,
  scanLvlUp = function() scanLvl = math.min(scanLvl+1, scanMaxLvl); changed = true end,
  scanLvlDown = function() scanLvl = math.max(0, scanLvl-1); changed = true end,
  refresh = function() changed = true end,
  close = close,
  toggleMode = toggleMode,
}
exitHandle = event.listen("interrupted", close)
keyDownHandle = keys.listen(keybinds, handlers)

local tick = 0
while running do
  tick = tick + 1
  if changed or tick % 20 == 0 then draw(tick); changed=false end
  local block = scanner.getScanBlock()
  if block.cnt < block.scan_cnt[scanLvl] then block.scan(1);
  else os.sleep(0.05) end
end
