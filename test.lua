package.path = './emul/?.lua;./misc/lib/?.lua;' .. package.path
exec = require "exec"
misc = require "misc"
scan = require "scan"

s = " a b"
print(s:match("a.?b"))

--local data = scan.init(-31,-31,1,64,64,1)
--while true do
--  local b = data.getScanBlock()
--  if b.cnt >= b.scan_cnt[1] then break end
--  b.scan(1)
--end
--local cnt, scan_cnt = data.getScanCnt()
--local blocks = data.getBlocks(1,1,1,8,8)
--print(data)
--print(cnt)
--print(misc._printTable(scan_cnt))
--print(misc._printTable(data.blocks[111]))
--print(misc._printTable(blocks))
--print(misc._printTable(data.getBlocks(3,3,1,1,1)[1].getData3D()[1]))
--print(misc._printTable(data.getRepr(1)))



--local coms, symb = {}
--symb = "abcdefg"; for i = 1, #symb do local s = symb:sub(i,i); 
--  coms[s] = {func = function() io.write(s) return true end, undo = function() io.write(string.upper(s)) return true end}
--end
--symb = "z"; for i = 1, #symb do local s = symb:sub(i,i); 
--  coms[s] = {func = function() io.write(s) return false end}
--end

--print(exec.check(coms))

--local pat = "[ab[#{z}@aa]@bbc@c]-1"
--print(pat)
--pat = exec.subArgs(pat, {a=2, b=-3, c=2})
--print(pat)
--print(table.unpack(coms))
--local newCommands = {["#"] = {func = function() io.write("@") return true end}}
--coms = misc.tWrap(coms) + newCommands
--misc._printTable(coms)
--local comsParsed = exec.parse(pat, coms)
--misc._printTable(comsParsed)
--print("##########")
--local res = {exec.exec(comsParsed)}
--print()
--print(table.unpack(res))

--print("##########")
--for com in exec.execIter(comsParsed) do end
--print()