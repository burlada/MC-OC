local comp=require("component")
local geo = comp.geolyzer

local m = {}
m._repr_air = " "
m._repr_unknown = "?"
m._repr_sym = {"░", "▒", "▓", "█", "≈"}
m._repr_val = {1, 1.75, 2.25, 10}
local bw, bd, bh = 8, 8, 1

function m.init(x, z, y, w, d, h)
  local bx, bz, by  = (w + (-w)%bw) / bw, (d + (-d)%bd) / bd, (h + (-h)%bh) / bh
  local blocks = {}
  for _x=1,bx do
    for _z=1,bz do
      for _y=1,by do
        local key, block = _x + _z*10 + _y*100
        do 
          local px, pz, py = x + (_x - 1) * bw, z + (_z -1) * bd, y + (_y - 1) * bh
          local lx = math.max(math.abs(px), math.abs(px+bw)) 
          local lz = math.max(math.abs(pz), math.abs(pz+bd)) 
          local ly = math.max(math.abs(py), math.abs(py+bh))
          local dist = math.sqrt(lx*lx + ly*ly + lz*lz)
          local s = 0.05/math.sqrt(2)*dist
          local v={}
          for _=1,bw*bd*bh do table.insert(v, 0) end
          block = {
            cnt=0, v=v,
            bx=_x, bz=_z, by=_y,
            x=px, z=pz, y=py,
            s=s
          }
        end
        blocks[key] = block
      end
    end
  end
  local data = {
    size=w*h*d, bsize=bx*by*bz,
    x=x, y=y, z=z, w=w, h=h, d=d,
    bx=bx, by=by, bz=bz, bw=bw, bh=bh, bd=bd,
    blocks = blocks
  }
  function data.getScanCnt(lvl,_y,_h,_x,_z,_w,_d) return m.getScanCnt(data,lvl,_y,_h,_x,_z,_w,_d) end
  function data.getBlocks(_x,_z,_y,_w,_d) return m.getBlocks(data,_x,_z,_y,_w,_d) end
  function data.getScanBlock(_x,_z,_y,_w,_d) return m.getScanBlock(data,_x,_z,_y,_w,_d) end
  function data.getNearestBlock(x,z,y) return m.getNearestBlock(data,x,z,y) end
  function data.getRepr(_y,_x,_z,_w,_d) return m.getRepr(data,_y,_x,_z,_w,_d) end
  return data
end

local scanLevels= {1, 7, 27, 54, 107, 211}
function m.getBlockNeed(b, lvl)
  if lvl <= 1 then return 1 end  
  return math.ceil(scanLevels[lvl]*b.s*b.s)
end

function m.getScanCnt(data, lvl, _y, _h, _x, _z, _w, _d)
  if not _y then _y,_h = 1, data.by end
  if not _x then _x,_z,_w,_d = 1, 1, data.bx, data.bz end
  local cnt, need = 0, 0
  for y=_y,_y+_h-1 do
    for z=_z,_z+_d-1 do
      for x=_x,_x+_w-1 do
        local key = x + z*10 + y*100
        local b = data.blocks[key]
        cnt, need = cnt + b.cnt, need + m.getBlockNeed(b, lvl)
      end
    end
  end
  return cnt, need
end

function m.getBlocks(data, _x, _z, _y, _w, _d)
  local res={}
  for __z=_z,_z+_d-1 do
    for __x=_x,_x+_w-1 do
      table.insert(res, data.blocks[__x+__z*10+_y*100])
    end
  end
  return res
end

function m._repr(value)
  if not value then return m._repr_unknown end
  if value == 0 then return m._repr_air end
  for p, threshold in ipairs(m._repr_val) do
    if value <= threshold then return m._repr_sym[p] end
  end
  return m._repr_sym[#m._repr_sym]
end

function m._getBlockData3D(block, bw, bd, bh)
  local res = {}
  for y=0,bh-1 do
    local level = {}
    for z=0,bd-1 do
      local line = {}
      for x=1,bw do
        if block and block.cnt > 0 and x <= bw and z < bd and y < bh then
          table.insert(line, block.v[x + z*bd + y*bd*bh] / block.cnt)
        else
          table.insert(line, false)
        end
      end
      table.insert(level, line)
    end
    table.insert(res, level)
  end
  return res
end

function m._getBlockRepr2D(block, y, bw, bd, bh)
  local level = m._getBlockData3D(block, bw, bd, bh)[y or 1]
  local res = {}
  for _,line in ipairs(level) do
    local _line = {}
    for _,value in ipairs(line) do table.insert(_line, m._repr(value)) end
    table.insert(res, table.concat(_line))
  end
  return res
end

function m.blockScan(b, cnt)
  for _=1,cnt or 1 do
    local res = geo.scan(b.x, b.z, b.y, bw, bd, bh)
    for i=1,#b.v do b.v[i] = b.v[i] + res[i] end
  end
  b.cnt = b.cnt + (cnt or 1)
end

function m.getRepr(data, _y, _x, _z, _w, _d)
  local bw, bd, bh = data.bw, data.bd, data.bh
  if not _x then _x, _z, _w, _d = 1, 1, data.bx, data.bz end
  local res={}
  for __z=0,_d-1 do
    for _=1,bd do table.insert(res, {}) end
    for __x=0,_w-1 do
      local block = data.blocks[(_x+__x) + (_z+__z)*10 + _y*100]
      local repr = m._getBlockRepr2D(block, 1, bw, bd, bh)
      for pz, line in ipairs(repr) do
        table.insert(res[pz + __z*bd], line)
      end
    end
    for pz=1,bd do res[pz + __z*bd] = table.concat(res[pz + __z*bd]) end
  end
  return res
end

function m.getScanBlock(data, _x, _z, _y, _w, _d)
  local blocks
  if not _x then blocks = data.blocks
  else blocks = m.getBlocks(data, _x, _z, _y, _w, _d) end
  local min_value, min_block = 1e+10, nil
  for _,b in pairs(blocks) do
    local value = b.cnt / b.s / b.s + b.s*1e-6
    if min_value > value then min_value, min_block = value, b end
  end
  return min_block
end

function m.getNearestBlock(data, x, z, y)
  if not x then x, z, y = 0, 0, 0 end
  local min_value, min_block = 1e+10, nil
  for _,b in pairs(data.blocks) do
    local cx,cy,cz = b.x+bw/2,b.y,b.z+bd/2
    local value = (cx-x)*(cx-x) + (cy-y)*(cy-y) + (cz-z)*(cz-z)
    if min_value > value then min_value, min_block = value, b end
  end
  return min_block
end

return m
