local comp=require("component")
local scan=require("scan")
local event=require("event")
local keys=require("keys")
local term=require("term")
local geo, gpu = comp.geolyzer, comp.gpu
local scrW, scrH = gpu.getResolution()
local keybinds = keys.loadConfig("/etc/scanner.cfg", {
  left = {{"left"}}, right = {{"right"}}, up = {{"up"}}, down = {{"down"}}, pageUp = {{"pageUp"}}, pageDown = {{"pageDown"}},
  scanLvlDown = {{"minus"}, {"numpadsub"}}, scanLvlUp = {{"shift", "equals"}, {"numpadadd"}},
  toggleMode = {{"space"}}, close = {{"control", "q"}}, home = {{"home"}},
})
local changed, scanMode, status = true, "none", "wait"
local bx,by,bz = 1,1,1
local scanW, scanD, scanLvl, scanMaxLvl, tick = 4, 2, 1, 6, 0
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

local function close()
  term.clear()
  print("Finish after: "..tostring(tick))
  os.exit(0)
end
local function home()
  local b = scanner.getNearestBlock()
  bx,bz,by = b.bx, b.bz, b.by
end
local function shift(dx,dz,dy)
  bx = math.max(1,math.min(bx+dx, scanner.bx-scanW+1))
  bz = math.max(1,math.min(bz+dz, scanner.bz-scanD+1))
  by = math.max(1,math.min(by+dy, scanner.by))
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
  local selfX, selfZ = -scanner.x-(bx-1)*scanner.bw, -scanner.z-(bz-1)*scanner.bd
  
  for z, line in ipairs(repr) do gpu.set(1, z, line) end
  if selfX >= 1 and selfZ >= 1 and selfX <= scanW*8 and selfZ <= scanD*8 then gpu.set(selfX, selfZ, "@") end
  gpu.fill(baseX, 1, scrW-baseX, scrH, " ")

  gpu.set(baseX,1, " Mode: "..scanMode)
  gpu.set(baseX,2, "  <"..status..">")
  gpu.set(baseX,3, " Tick: "..tostring(tick))
  gpu.set(baseX,4, " Scan: "..tostring(scans))
  gpu.set(baseX,5, " Lvl: "..tostring(scanLvl).."->"..tostring(sizes[scanLvl]))
  gpu.set(baseX,6, " Bxyz: "..tostring(bx)..tostring(bz)..tostring(by))
  gpu.set(baseX,7, " P: "..tostring(cx).." "..tostring(cz).." "..tostring(cy))
end
local handlers = {
  left = function() shift(-1, 0, 0) end,
  right = function() shift(1, 0, 0) end,
  up = function() shift(0, -1, 0) end,
  down = function() shift(0, 1, 0) end,
  pageUp = function() shift(0, 0, 1) end,
  pageDown = function() shift(0, 0, -1) end,
  scanLvlUp = function() scanLvl = math.min(scanLvl+1, scanMaxLvl) end,
  scanLvlDown = function() scanLvl = math.max(1, scanLvl-1) end,
  home = home,
  close = close,
  toggleMode = toggleMode,
}
local keyHandler = keys.getHandler(keybinds, handlers)

home()
local block
while true do
  tick = tick + 1
  if changed or tick % 20 == 0 then draw(tick); changed=false end  
  status = "wait"
  if scanMode == "none" then --pass
  elseif scanMode == "window" then
    block = scanner.getScanBlock(bx,bz,by,scanW,scanD)
    if block.cnt < block.scan_cnt[scanLvl] then block.scan(1); status = "scan window" end
  elseif scanMode == "full" then
    block = scanner.getScanBlock(bx,bz,by,scanW,scanD)
    if block.cnt < block.scan_cnt[scanLvl] then block.scan(1); status = "scan window"
    else
      block = scanner.getScanBlock(1,1,by,scanner.bx,scanner.bz)
      if block.cnt < block.scan_cnt[scanLvl] then block.scan(1); status = "scan level"
      else
        block = scanner.getScanBlock()
        if block.cnt < block.scan_cnt[scanLvl] then block.scan(1); status = "scan full" end
      end
    end
  end
  local event, addr, arg1, arg2 = event.pullMultiple( (status=="wait") and 0.05 or 0, "key_down", "interrupted")
  if event == "interrupted" then close()
  elseif event == "key_down" then keyHandler(event, addr, arg1, arg2); changed=true end
end
