local m = {}

function m.preq(...)
  local status, lib = pcall(require, ...)
  if status then return lib else print("Fail to load lib") end
  return nil
end

local internet = m.preq("internet")
local serialization = m.preq("serialization")
local fs = require("filesystem")
local userGitPassFile = "/etc/user_git_pass"
local mcocModsFile = "/etc/mcoc_mods"

function m.unrequire(...)
  for _, lib in ipairs(table.pack(...)) do package.loaded[lib] = nil end
end
function m.tableKeys(t)
  local keyset, n = {}, 0
  for k, _ in pairs(t) do n = n + 1; keyset[n] = k end
  return keyset
end
function m.time() return os.time() / 72; end
function m.formatTime(t) 
  if t == nil then t = m.time(); end
  local h = math.floor(t / 3600)
  local m = math.floor((t - h * 60) / 60)
  local s = t - h * 3600 - m * 60
  return string.format("%03d:%02d:%02d", h, m, s)
end
function m.printTableKeys(tab, sep) 
  sep = sep or ", "
  for k,_ in pairs(tab) do io.write(serialization.serialize(k)..sep); end
  print()
end
function m.printTableValues(tab, sep)
  sep = sep or ", "
  for _,v in pairs(tab) do io.write(serialization.serialize(v)..sep); end
  print()
end
function m.printTable(tab, sep)
  sep = sep or "\n"
  for k,v in pairs(tab) do io.write(serialization.serialize(k).."="..serialization.serialize(v)..sep); end
  print()
end
function m._printTable(t, sep, sS, fS)
  io.write(sS or "")
  local isFirst = true
  for k,v in pairs(t) do 
    if isFirst then isFirst = false else io.write(sep or "\n") end
    io.write(tostring(k).."=")
    if type(v) == "table" then m._printTable(v, ",", "{", "}")
    elseif type(v) == "string" then io.write("'"..v.."'")
    else io.write(tostring(v)) end
  end
  io.write(fS or "")
  if not sep or sep == "\n" then print() end
end
local tMeta = {}
function tMeta.__add(t1, t2)
  local res = {}
  for k, v in pairs(t1) do res[k] = v end
  for k, v in pairs(t2) do res[k] = v end
  setmetatable(res, tMeta)
  return res
end
function m.tWrap(t) setmetatable(t, tMeta) return t end
function m.ser(t) return serialization.serialize(t) end
function m.unser(t) return serialization.unserialize(t) end


local ext = bit32.extract
local enc, dec, s62, s63 = {}, {}, '+', '/'
for b64code, char in pairs{[0]='A','B','C','D','E','F','G','H','I','J',
	'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y',
	'Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
	'o','p','q','r','s','t','u','v','w','x','y','z','0','1','2',
	'3','4','5','6','7','8','9',s62,s63,'='} do
	enc[b64code] = char:byte()
	dec[char:byte()] = b64code
end
local char, concat = string.char, table.concat

function m.encode64(str)
	local t, k, n = {}, 1, #str
	local lastn = n % 3
	for i = 1, n-lastn, 3 do
		local a, b, c = str:byte(i, i+2)
		local v = a*0x10000 + b*0x100 + c
		t[k] = char(enc[ext(v,18,6)], enc[ext(v,12,6)], enc[ext(v,6,6)], enc[ext(v,0,6)])
		k = k + 1
	end
	if lastn == 2 then
		local a, b = str:byte(n-1, n)
		local v = a*0x10000 + b*0x100
		t[k] = char(enc[ext(v,18,6)], enc[ext(v,12,6)], enc[ext(v,6,6)], enc[64])
	elseif lastn == 1 then
		local v = str:byte(n)*0x10000
		t[k] = char(enc[ext(v,18,6)], enc[ext(v,12,6)], enc[64], enc[64])
	end
	return concat(t)
end

function m.decode64(b64)
	b64 = b64:gsub('[^%w%+%/%=]', '')
	local t, k, n = {}, 1, #b64
	local padding = b64:sub(-2) == '==' and 2 or b64:sub(-1) == '=' and 1 or 0
	for i = 1, padding > 0 and n-4 or n, 4 do
		local a, b, c, d = b64:byte(i, i+3)
		local v = dec[a]*0x40000 + dec[b]*0x1000 + dec[c]*0x40 + dec[d]
		t[k] = char(ext(v,16,8), ext(v,8,8), ext(v,0,8))
		k = k + 1
	end
	if padding == 1 then
		local a, b, c = b64:byte(n-3, n-1)
		local v = dec[a]*0x40000 + dec[b]*0x1000 + dec[c]*0x40
		t[k] = char(ext(v,16,8), ext(v,8,8))
	elseif padding == 2 then
		local a, b = b64:byte(n-3, n-2)
		local v = dec[a]*0x40000 + dec[b]*0x1000
		t[k] = char(ext(v,16,8))
	end
	return concat(t)
end

function m.parseJson(str)
  return load("return"..str:gsub("%[","{"):gsub("%]","}"):gsub('(".-"):(.-[,{}])',function(a,b) return "["..a.."]="..b end))()
end

if internet then
  function m.fetchFile(url, headers)
    print("Fetching: "..url)
    local result,response=pcall(internet.request, url, nil, headers)
    local chunks = {}
    if result then
      for chunk in response do table.insert(chunks, chunk) ;io.write("."); end
      print("Done")
    else error("Request failed: "..(response or "") end
    return table.concat(chunks)
  end

  local gitPattern = "https://api.github.com/repos/%s/contents/%s?ref=master"
  function m.fetchGitFile(repo, path)
    local url = gitPattern:format(repo, path)
    local userPass = m.getUserGitPass()
    local headers = userPass and {Authorization = "Basic "..m.encode64(userPass)}
    local data = assert(m.parseJson(assert(m.fetchFile(url, headers), "Git 404")), "Git return not json")
    data = assert(data.content, "Git response: "..(data.message or "None"))
    return m.decode64(data)
  end
  
  function m.wgetFile(url, filename, override)
    if override then pcall(fs.remove, filename) end
    local data = assert(m.fetchFile(url))
    local file = assert(io.open(filename, "wb"))
    file:write(data)
    file:close()
  end
  
  function m.wgetGitFile(repo, path, filename, override)
    if override then pcall(fs.remove, filename) end
    local data = assert(m.fetchGitFile(repo, path))
    local file = assert(io.open(filename, "wb"))
    file:write(data)
    file:close()
  end    

  function m.executeGitCode(repo, path)
    local data = assert(m.fetchGitFile(repo, path))
    return load(data)()
  end
end

function m.readSerFile(path)
  local file = assert(io.open(path, "r"))
  local res = assert(serialization.unserialize(file:read("*a")))
  file:close()
  return res
end

function m.writeSerFile(path, obj)
  local file = assert(io.open(path, "wb"))
  file:write(assert(serialization.serialize(obj)))
  file:close()
end

function m.getMods() 
  local status, res = pcall(m.readSerFile, mcocModsFile)
  return status and res or {}
end
function m.getUserGitPass()
  local status, res = pcall(m.readSerFile, userGitPassFile)
  return status and res or nil
end
function m.setUserGitPass(userPass)
  m.writeSerFile(userGitPassFile, userPass)
end
function m.registerMod(mod, conf)
  local mods = m.getMods()
  if mods[mod] then return mods, "module already added" end
  mods[mod] = conf or {}
  m.writeSerFile(mcocModsFile, mods)
  return mods
end
function m.unregisterMod(mod)
  local mods = m.getMods()
  if not mods[mod] then return mods, "module not found" end
  mods[mod] = nil
  m.writeSerFile(mcocModsFile, mods)
  return mods
end

function m.reload()
  local modulesToLoad = {}
  for mod, conf in pairs(m.getMods()) do
    for _, info in pairs(conf.files) do
      if info._module and info._module ~= "misc" then
        print("Unload", mod, info._module)
        table.insert(modulesToLoad, info._module)
        m.unrequire(info._module)
      end
    end
  end
  print("Unload", "misc")
  m.unrequire("misc")
  print("Load", "misc")
  require("misc")
  for _, _module in ipairs(modulesToLoad) do
    print("Load", _module)
    require(_module)
  end
end

return m

