local command, arg = ...
local gitrepo = "burlada/MC-OC"
local gitraw = "https://raw.githubusercontent.com/"..gitrepo.."/master/"
local generalFiles = {
  ["misc/lib/misc.lua"] = {path = "/lib/misc.lua", _module = "misc"},
  ["setup.lua"] = {path = "/bin/setup.lua"},
}
local mods = {
  ["robot"] = {config = "robot/config.lua", desc = "Basic robot operations"},
  ["misc"] = {config = "misc/config.lua", desc = "Misc))"},
}

local fs = require("filesystem")

local function rawUpdateGeneralFiles()
  local shell = require("shell")
  for gitfile,info in pairs(generalFiles) do
    shell.execute("wget -f "..gitraw..gitfile.." "..info.path)
  end
end

local function updateGeneralFiles(misc_module)
  for gitfile,info in pairs(generalFiles) do
    misc_module.wgetGitFile(gitrepo, gitfile, info.path, true)
  end
end

local status, misc = pcall(require, "misc")

if not status then
  rawUpdateGeneralFiles()
  misc = require("misc")
end

local function getModsFiles(mod) return misc.getMods()[mod].files end
local function removeMod(mod)
  local desc = misc.getMods()[mod]
  if not desc then return end
  print("Removing: "..mod)
  for _, info in pairs(desc.files) do
    pcall(fs.remove, info.path)
  end
  misc.unregisterMod(mod)
end
local function installMod(mod)
  local conf = assert(mods[mod])
  removeMod(mod)
  local desc = misc.executeGitCode(gitrepo, conf.config)
  for gitfile,info in pairs(desc.files) do
    misc.wgetGitFile(gitrepo, gitfile, info.path, true)
  end
  misc.registerMod(mod, desc)
end

local function update(mod)
  if mod then installMod(mod) return end
  updateGeneralFiles(misc)
  for mod,_ in pairs(misc.getMods()) do installMod(mod)end
end

local function printFiles(mod)
  if not mod then
    misc.printTable(generalFiles)
  else
    misc.printTable(getModsFiles(mod))
  end
end

local function printMods()
  local installed = misc.getMods()
  for k, v in pairs(mods) do
    local mark = installed[k] and "X" or " "
    print(k.."["..mark.."] "..v.desc)
  end
end

local function reload()
  print(misc.reload())
end

local function auth(userPass)
  misc.setUserGitPass(userPass)
end

local commands = {
  auth = {func = auth, desc = "User:Password auth for git", short="a"},
  update = {func = update, desc = "Update all", short="u"},
  install = {func = installMod, desc = "Install mod", short="i"},
  files = {func = printFiles, desc = "Self or mod files", short="l"},
  mods = {func = printMods, desc = "List mods", short="m"},
  remove = {func = removeMod, desc = "Remove mod", short="d"},
  reload = {func = reload, desc = "Reload all", short="r"},
}
local shortCommands = {}
for _, v in pairs(commands) do if v.short then shortCommands[v.short] = v end end
local commandFunc = commands[command] or shortCommands[command]
if not commandFunc then
  print("Avaliable commands:")
  for k, v in pairs(commands) do print(" "..k.."["..(v.short or "").."]: "..v.desc.."") end
  os.exit(0)
end
commandFunc.func(arg)