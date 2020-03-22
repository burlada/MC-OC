local move = require("move")
if #{...} > 0 then
  local command = table.concat({...})
  local status, cnt, time, err = move.play(command)
  print(status, cnt, time, err)
  os.exit(status and 0 or 1)
end

local term = require("term")
local shell = require("shell")
local gpu = term.gpu()

gpu.setForeground(0xFFFF00)
term.write("Enter move commands.\n")
term.write("Press Ctrl+D to exit the interpreter.\n")
gpu.setForeground(0xFFFFFF)

  while term.isAvailable() do
    local foreground = gpu.setForeground(0x00FF00)
    term.write(tostring(env._PROMPT or "lua> "))
    gpu.setForeground(foreground)
    local command = term.read(history, nil, hint)
    if not command then -- eof
      return
    end
    local code, reason
    if string.sub(command, 1, 1) == "=" then
      code, reason = load("return " .. string.sub(command, 2), "=stdin", "t", env)
    else
      code, reason = load(command, "=stdin", "t", env)
    end
    if code then
      local result = table.pack(xpcall(code, debug.traceback))
      if not result[1] then
        if type(result[2]) == "table" and result[2].reason == "terminated" then
          os.exit(result[2].code)
        end
        io.stderr:write(tostring(result[2]) .. "\n")
      else
        for i = 2, result.n do
          term.write(require("serialization").serialize(result[i], true) .. "\t", true)
        end
        if term.getCursor() > 1 then
          term.write("\n")
        end
      end
    else
      io.stderr:write(tostring(reason) .. "\n")
    end
  end
end