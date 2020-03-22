local m = {}
local braces = { ["("] = "^%b()", ["["] = "^%b[]", ["{"] = "^%b{}" }

local function parseGroup(str, pos, allowed)
  if pos > #str then return nil, pos end
  local b = str:sub(pos, pos)
  if not allowed:find(b, 1, true) then return nil, pos end
  local s, f = str:find(braces[b], pos)
  if not s then error("Invalid braces ["..b.."] at "..pos) end
  return str:sub(s+1, f-1), f + 1
end

local function parseCnt(str, pos)
  local s, f = str:find("^[+-]?%d+", pos)
  if not s then return nil, pos end
  return tonumber(str:sub(s, f)), f + 1
end

function m.check(commands)
  local prefixes = {}
  for k, com in pairs(commands) do
    if not k:match("^[%a#][%w_]*$") then return nil, "Command ["..k.."] is illegal" end
    if not com.func then return nil, "Command "..k.." doesn't have func property" end
    for i = 1, #k - 1 do prefixes[k:sub(1, i)] = k end
  end
  for k, _ in pairs(commands) do
    if prefixes[k] then return nil, "Command ["..k.."] is a prefix of ["..prefixes[k].."] " end
  end
  return true
end

function m.exec(parsedCommand, undo, yeild)
  assert(parsedCommand.coms, "Command should be parsed")
  undo = undo and true or false
  local sTime, cnt, size = os.time(), 0, #parsedCommand.coms
  local from, to, step = table.unpack(undo and {size, 1, -1} or {1, size, 1})
  for pos = from,to,step do
    local com = parsedCommand.coms[pos]
    for _ = 1, math.abs(com.cnt) do
      local status, err, steps
      if com.coms and not com.func and not com.undo then
        status, steps, _, err = m.exec(com, undo == (com.cnt > 0), yeild)
      else
        if yeild then coroutine.yield(com) end
        if not undo then
          status, err = com.func(com.arg)
        elseif com.undo then
          status, err = com.undo(com.arg)
        else
          status, err = true
        end
        steps = com.steps or 1
      end
      cnt = cnt + steps
      if not status then return parsedCommand.silent, cnt, (os.time() - sTime) / 72, err end
    end
  end
  return true, cnt, (os.time() - sTime) / 72
end

function m.execIter(parsedCommand, undo)
  assert(parsedCommand.coms, "Command should be parsed")
  return coroutine.wrap(function() m.exec(parsedCommand, undo, true) end)
end

function m.subArgs(command, args)
  assert(type(command) == "string")
  local iter = 1
  while command:find("@") do
    for k, v in pairs(args) do
      assert(type(v) == "number" or type(v) == "string", "Invalid arg type")
      command = command:gsub("@"..tostring(k), tostring(v))
    end
    iter = iter + 1;
    assert(iter < 5, "To many sub iterations. Possibly infinite loop")
  end
  return command
end

function m.parse(str, commands, silent)
  assert(m.check(commands))
  local result = {name = "[", silent = silent, coms = {}, cnt = 1}
  if #str == 0 then return result end
  local pos = 1
  while pos <= #str do
    local fin, com, arg, cnt, name = pos
    com, fin = parseGroup(str, pos, "[{")
    if com then
      com = m.parse(com, commands, str:sub(pos, pos) == "{")
      name = str:sub(pos, pos)
    else
      repeat
        name = str:sub(pos, fin)
        fin, com = fin + 1, commands[name]
      until com or fin > #str
      if not com then error("Unknow command at "..pos) end
    end
    arg, fin = parseGroup(str, fin, "(")
    cnt, fin = parseCnt(str, fin)
    table.insert(result.coms, {
        func=com.func,
        undo=com.undo,
        name=com.name or name,
        silent = com.silent,
        coms = com.coms,
        arg = arg or com.arg,
        cnt = cnt or com.cnt or 1
    })
    pos = fin
  end
  return result
end

return m