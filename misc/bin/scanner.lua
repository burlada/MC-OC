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
  toggleMode = {{"space"}}, close = {{"control", "q"}}, home = {{"home"}}, toggleSelf = {{"h"}},
  forcePageUp={{"control", "pageUp"}}, forcePageDown={{"control", "pageDown"}}, activate={{"control", "return"}},
  save={{"control", "s"}}
})
local changed, scanMode, status, showSelf = true, "none", "wait", true
local bx,by,bz = 1,1,1
local scanW, scanD, scanLvl, scanMaxLvl, tick = 4, 2, 1, 6, 0
local baseX,startTime = scanW*8+2, os.time()
local fakeLevels = {}
local scanner 
do
  local y,h,x,w,z,d = ...
  if not y or not geo or not gpu then
    print("Usage: scanner y h x w z d")
    print("Need geolyzer and screen")
    print(keys.help(keybinds))
    os.exit(0)
  end

  scanner = scan.init(
    tonumber(x or "-32"), tonumber(z or "-32"), tonumber(y or "0"),
    tonumber(w or "64"), tonumber(d or "64"), tonumber(h or "1"))
end
gpu.fill(1,1,scrW,scrH," ")
gpu.fill(1+scanW*8,1,1,scrH,"‖")
gpu.fill(1,1+scanD*8,scrW,1,"=")

local function close()
  term.clear()
  print("Finish after: "..tostring(tick))
  os.exit(0)
end
local function normalize()
  bx = math.max(1,math.min(bx, scanner.bx-scanW+1))
  bz = math.max(1,math.min(bz, scanner.bz-scanD+1))
  if not fakeLevels[scanner.y+by-1] then 
    by = math.max(1,math.min(by, scanner.by))
  end
end
local function home()
  local b = scanner.getNearestBlock()
  bx,bz,by=b.bx-1,b.bz-1,b.by
  normalize()
end
local function shift(dx,dz,dy)
  bx,bz,by=bx+dx,bz+dz,by+dy
  normalize()
end
local function activate(dy)
  if ny == scanner.y then return end
  local x, z, y, w, d = scanner.x, scanner.z, scanner.y, scanner.w, scanner.d
  fakeLevels[scanner.y] = scanner.getRepr(1)
  scanner = nil
  scanner = scan.init(x,z,y+dy,w,d,1)
  by=1
end
local function forceShift(dy)
  local oby = by
  by=by+dy
  normalize()
  if by ~= oby then return end
  activate(dy)
end
local function toggleMode()
  if scanMode == "none" then scanMode = "window"
  elseif scanMode == "window" then scanMode = "full"
  else scanMode = "none" end
end
local function sliceRepr(repr)
  local res = {}
  local sx,fx = 1+(bx-1)*8,(bx+scanW-1)*8
  for z=1+(bz-1)*8,(bz+scanD-1)*8 do table.insert(res, repr[z]:sub(sx,fx)) end
  return res
end
local function save()
  local repr = fakeLevels[scanner.y+by-1]
  if not repr then repr = scanner.getRepr(1) end
  local f = assert(io.open("/tmp/save_level_"..tostring(scanner.y+by-1), "wb"))
  for _, line in ipairs(repr) do
    f:write(line)
    f:write("\n")
  end
  f:close()
end
local function draw(tick)
  local cx,cz,cy = scanner.x+(bx-1+scanW/2)*scanner.bw, scanner.z+(bz-1+scanD/2)*scanner.bd, scanner.y+(by-1)*scanner.bh
  local selfX, selfZ = 1-scanner.x-(bx-1)*scanner.bw, 1-scanner.z-(bz-1)*scanner.bd
  local repr, scansWin, needWin, scansLevel, needLevel
  if not fakeLevels[scanner.y+by-1] then
    repr = scanner.getRepr(by,bx,bz,scanW,scanD)
    scansWin, needWin = scanner.getScanCnt(scanLvl,by,1,bx,bz,scanW,scanD)
    scansLevel, needLevel = scanner.getScanCnt(scanLvl,by,1)
  else
    repr = sliceRepr(fakeLevels[scanner.y+by-1])
  end
  for z, line in ipairs(repr) do gpu.set(1, z, line) end
  if selfX >= 1 and selfZ >= 1 and selfX <= scanW*8 and selfZ <= scanD*8 and showSelf then gpu.set(selfX, selfZ, "@") end
  gpu.fill(baseX, 1, scrW-baseX, scrH, " ")

  gpu.set(baseX,1, " Mode: "..scanMode)
  gpu.set(baseX,2, "  <"..status..">")
  gpu.set(baseX,3, " Tick: "..tostring(tick))
  gpu.set(baseX,4, " Time: "..tostring(math.ceil((os.time()-startTime)/72)))
  gpu.set(baseX,6, " Lvl: "..tostring(scanLvl))
  if not fakeLevels[scanner.y+by-1] then
    gpu.set(baseX,7, " *W: "..tostring(scansWin).."/"..tostring(needWin))
    gpu.set(baseX,8, " *L: "..tostring(scansLevel).."/"..tostring(needLevel))
  end
  gpu.set(baseX,10, " Bxyz: "..tostring(bx)..tostring(bz)..tostring(by))
  gpu.set(baseX,11, " ScanY: "..tostring(scanner.y).." "..tostring(scanner.h))
  gpu.set(baseX,12, " P: "..tostring(cx).." "..tostring(cz).." "..tostring(cy))
end
local handlers = {
  left = function() shift(-1, 0, 0) end,
  right = function() shift(1, 0, 0) end,
  up = function() shift(0, -1, 0) end,
  down = function() shift(0, 1, 0) end,
  pageUp = function() shift(0, 0, 1) end,
  pageDown = function() shift(0, 0, -1) end,
  pageUp = function() shift(0, 0, 1) end,
  pageDown = function() shift(0, 0, -1) end,
  forcePageUp = function() forceShift(1) end,
  forcePageDown = function() forceShift(-1) end,
  activate = function() forceShift(0) end,
  scanLvlUp = function() scanLvl = math.min(scanLvl+1, scanMaxLvl) end,
  scanLvlDown = function() scanLvl = math.max(1, scanLvl-1) end,
  toggleSelf = function() showSelf = not showSelf end,
  save = save,
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
  if fakeLevels[scanner.y+by-1] then status="FAKE"
  elseif scanMode == "none" then --pass
  elseif scanMode == "window" then
    block = scanner.getScanBlock(bx,bz,by,scanW,scanD)
    if block.cnt < scan.getBlockNeed(block, scanLvl) then scan.blockScan(block, 1); status = "scan window" end
  elseif scanMode == "full" then
    block = scanner.getScanBlock(bx,bz,by,scanW,scanD)
    if block.cnt < scan.getBlockNeed(block, scanLvl) then scan.blockScan(block, 1); status = "scan window"
    else
      block = scanner.getScanBlock(1,1,by,scanner.bx,scanner.bz)
      if block.cnt < scan.getBlockNeed(block, scanLvl) then scan.blockScan(block, 1); status = "scan level"
      else
        block = scanner.getScanBlock()
        if block.cnt < scan.getBlockNeed(block, scanLvl) then scan.blockScan(block, 1); status = "scan full" end
      end
    end
  end
  local wait = (status=="wait" or status=="FAKE") and 0.05 or 0
  local event, addr, arg1, arg2 = event.pullMultiple(wait, "key_down", "interrupted")
  if event == "interrupted" then close()
  elseif event == "key_down" then keyHandler(event, addr, arg1, arg2); changed=true end
end
