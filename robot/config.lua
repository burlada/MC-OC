return {
  name = "robot",
  files = {
    ["robot/boot/80_navigation.lua"] = {path = "/boot/80_navigation.lua"},
    ["robot/lib/move.lua"] = {path = "/lib/move.lua", _module = "move"},
    ["robot/bin/go.lua"] = {path = "/bin/go.lua"},
    ["robot/bin/pipe.lua"] = {path = "/bin/pipe.lua"},
  }
}