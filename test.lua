package.path = './emul/?.lua;./misc/?.lua;' .. package.path
exec = require "exec"
misc = require "misc"



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