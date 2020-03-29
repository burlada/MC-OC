local comp=require("component")
local geo = comp.geolyzer

local m = {}
m._repr_air = " "
m._repr_unknown = "?"
m._repr_sym = {"░", "▒", "█", "≈"}
m._repr_val = {1, 2.25, 10}

function m.init(x, z, y, w, d, h)
  local bw, bd, bh = 8, 8, 1
  local bx, bz, by  = (w + (-w)%bw) / bw, (d + (-d)%bd) / bd, (h + (-h)%bh) / bh
  local blocks = {}
  for _x=1,bx do
    for _z=1,bz do
      for _y=1,by do
        local key = _x + _z*10 + _y*100
        local px, pz, py = x + (_x - 1) * bw, z + (_z -1) * bd, y + (_y - 1) * bh
        local rbw, rbd, rbh = _x*bw<=w and bw or w%bw, _z*bd<=d and bd or d%bd, _y*bh<=h and bh or h%bh
        local lx = math.max(math.abs(px), math.abs(px+rbw)) 
        local lz = math.max(math.abs(pz), math.abs(pz+rbd)) 
        local ly = math.max(math.abs(py), math.abs(py+rbh)) 
        local dist = math.sqrt(lx*lx + ly*ly + lz*lz)
        local sigma = 0.05/math.sqrt(2)*dist
        local scan_cnt = {
          1, -- scan for air/water -- 0% error +-10
          math.ceil(7*sigma*sigma), -- 1% error +-1
          math.ceil(27*sigma*sigma), -- 1% error +-0.5
          math.ceil(54*sigma*sigma), -- ~1 error +- 0.5 per 64x64
          math.ceil(107*sigma*sigma), -- 1% error +- 0.25
          math.ceil(211*sigma*sigma), -- ~1 error +- 0.25 per 64*64
        }
        local values={}
        for _=1,rbw*rbd*rbh do table.insert(values, 0) end
        local block = {
          dist=dist, sigma=sigma, scan_cnt=scan_cnt,
          cnt=0, size=rbw*rbd*rbh, values=values,
          x=px, z=pz, y=py, w=rbw, d=rbd, h=rbh,
          bx=_x, bz=_z, by=_y,
        }
        function block.getData3D() return m._getBlockData3D(block, bw, bd, bh) end
        function block.getRepr2D(y) return m._getBlockRepr2D(block, y, bw, bd, bh) end
        function block.scan(cnt) return m._blockScan(block, cnt) end
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
  function data.getScanCnt() return m.getScanCnt(data) end
  function data.getBlocks(_x,_z,_y,_w,_d) return m.getBlocks(data,_x,_z,_y,_w,_d) end
  function data.getScanBlock(_x,_z,_y,_w,_d) return m.getScanBlock(data,_x,_z,_y,_w,_d) end
  function data.getNearestBlock(x,z,y) return m.getNearestBlock(data,x,z,y) end
  function data.getRepr(_y,_x,_z,_w,_d) return m.getRepr(data,_y,_x,_z,_w,_d) end
  return data
end

function m.getScanCnt(data)
  local cnt, scan_cnt = 0, {0,0,0,0,0,0}
  for _,b in pairs(data.blocks) do
    cnt = cnt + b.cnt
    for i=1,6 do scan_cnt[i] = scan_cnt[i] + b.scan_cnt[i] end
  end
  return cnt, scan_cnt
end

function m.getBlocks(data, _x, _z, _y, _w, _d)
  local res={}
  for __z=_z,_z+_d do
    for __x=_x,_x+_w do
      table.insert(res, data.blocks[__x+__z*10+_y*100])
    end
  end
  return res
end

function m.getBlocks(data, _x, _z, _y, _w, _d)
  local res={}
  for __z=_z,_z+_d do
    for __x=_x,_x+_w do
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
        if block.cnt > 0 and x <= block.w and z < block.d and y < block.h then
          table.insert(line, block.values[x + z*bd + y*bd*bh] / block.cnt)
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

function m._blockScan(b, cnt)
  for _=1,cnt or 1 do
    local res = geo.scan(b.x, b.z, b.y, b.w, b.d, b.h)
    for i=1,b.size do b.values[i] = b.values[i] + res[i] end
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
    local value = b.cnt / b.sigma / b.sigma + b.dist*1e-6
    if min_value > value then min_value, min_block = value, b end
  end
  return min_block
end

function m.getNearestBlock(data, x, z, y)
  if not x then x, z, y = 0, 0, 0 end
  local min_value, min_block = 1e+10, nil
  for _,b in pairs(data.blocks) do
    local cx,cy,cz = b.px+b.w/2,b.py+b.h/2,b.pz+b.d/2
    local value = (cx-x)*(cx-x) + (cy-y)*(cy-y) + (cz-z)*(cz-z)
    if min_value > value then min_value, min_block = value, b end
  end
  return min_block
end

return m
