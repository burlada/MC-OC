local event = require("event")
local fs = require("filesystem")
local keyboard = require("keyboard")
local unicode = require("unicode")
local serialize = require("serialization").serialize
local m = {}

local cmdCheck = {
  alt=keyboard.isAltDown,
  control=keyboard.isControlDown,
  shift=keyboard.isShiftDown,
}

-- defaults Map<Name, List<Command>>; command = {"<key>"} | {"<cmd>", "<key>"}
-- ex keybinds={left = {{"left"}}, findnext = {{"control", "g"}, {"control", "n"}, {"f3"}}}
function m.loadConfig(path, default)
  local env, config = {}
  if path then
    config = loadfile(path, nil, env)
    if config then pcall(config) end
  end
  env.keybinds = assert(env.keybinds or default)
  -- validate
  for _, keybind in pairs(env.keybinds) do
    for _, bind in ipairs(keybind) do
      for pos, cmd in ipairs(bind) do
        if pos < #bind then assert(cmdCheck[cmd]) end
      end
    end
  end
  if path and not config then
    fs.makeDirectory(fs.path(path))
    local f = assert(io.open(path, "wb"))
    f:write("keybinds="..serialize(env.keybinds, math.huge).."\n")
    f:close()
  end
  return env.keybinds
end

function m.help(keybinds)
  local function printCommand(keybind)
    local res={}
    for _, bind in ipairs(keybind) do table.insert(res, table.concat(bind, "+")) end
    return table.concat(res, ", ")
  end
  local result = {}
  for name,keybind in pairs(keybinds) do table.insert(result, name..": "..printCommand(keybind)) end
  return table.concat(result, "\n")
end

function m.getKeybind(code, keybinds, handlers)
  assert(type(keybinds) == "table")
  local res, resName, resWeight = nil, nil, 0
  for name, keybind in pairs(keybinds) do
    if handlers[name] then
      for _, bind in ipairs(keybind) do
        if #bind > resWeight then
          local valid = code == keyboard.keys[bind[#bind]]
          for _, cmd in ipairs({table.unpack(bind,1,#bind-1)}) do
            valid = valid and cmdCheck[cmd]()
          end
          if valid then res,resName,resWeight = handlers[name],name,#bind end
        end
      end
    end
  end
  return res, resName
end

function m.listenKeyDown(keybinds, handlers, input)
  local function keyDown(_, _, char, code)
    local handler = m.getKeybind(code, keybinds, handlers)
    if handler then handler()
    elseif input and not keyboard.isControl(char) then
        input(unicode.char(char))
    elseif input and unicode.char(char) == "\t" then
        input("  ")
    end
  end
  return event.listen("key_down", keyDown)
end

return m