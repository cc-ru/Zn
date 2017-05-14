local com = component
local comp = computer

local modem = com.proxy(com.list("modem")())
local zn = {}

local PORT = 419
local CODES = {
  send = "Zn/send",
  ping = "Zn/ping",
  pong = "Zn/pong"
}

local FLAGS = {
}

local HASHLIFETIME = 43200
local MAXHASHCOUNT = 500
local isConnected = false

local hashes = {}

local function getTime()
  return tonumber(tostring(os.clock()):gsub("%.",""),10)
end

local function hashgen(time, data)
  return string.char(math.random(0, 255), math.random(0, 255),
                     math.random(0, 255), math.random(0, 255))
end

local function dateSorted(tbl)
  local values = {}
  for k in pairs(tbl) do
    table.insert(values, k)
  end
  table.sort(values, function(lhs, rhs)
    return tbl[lhs] < tbl[rhs]
  end)
  local i = 0
  return function()
    i = i + 1
    if not values[i] then
      return nil
    end
    return values[i], tbl[values[i]]
  end
end

local function check(hash)
  local time = comp.uptime()
  local len = 0
  for k, v in pairs(hashes) do
    len = len + 1
    if time - v > HASHLIFETIME then
      len = len - 1
      hashes[k] = nil
    end
  end
  while len > MAXHASHCOUNT do
    local k = dateSorted(hashes)()
    table.remove(hashes, k)
    len = len - 1
  end
  if not hashes[hash] then
    hashes[hash] = comp.uptime()
    return true
  end
  return hashes[hash] == nil
end

local function parseFlags(str)
  local flags = {}
  for n = 1, #str, 1 do
    local b = str:sub(n, n)
    local flag
    for k, v in pairs(FLAGS) do
      if v == b then
        flag = k
      end
    end
    if flag then
      table.insert(flags, flag)
      flags[flag] = true
    end
  end
  return flags
end

local function packFlags(flags)
  local str = ""
  for k, v in pairs(flags) do
    if FLAGS[k] then
      str = str .. FLAGS[k]
    end
  end
  return str
end

local function send(selfAddress, address, message, hash, code, flags)
  local hash = hash or hashgen(getTime(), message)
  hashes[hash] = comp.uptime()
  zn.modem.broadcast(PORT, code, address, selfAddress, hash, flags, message)
end

local function listener(name, receiver, sender, port, distance,
                        code, recvAddr, sendAddr, hash, flags, body)
  if receiver == zn.modem.address then
    if port == PORT and (
        code == CODES.send or
        code == CODES.pong or
        code == CODES.ping) then
      if code == CODES.ping then
        comp.pushSignal("zn_ping", sender, distance)
        zn.modem.send(sender, PORT, CODES.pong)
        return true
      end
      if code == CODES.pong then
        comp.pushSignal("zn_pong", sender, distance)
        return true
      end
      if check(hash) then
        if recvAddr == zn.modem.address or recvAddr == "" then
          if code == CODES.send then
            comp.pushSignal("zn_message", body, recvAddr, sendAddr)
          end
        end
        if recvAddr ~= zn.modem.address then
          send(sendAddr, recvAddr, body, hash, code, flags)
        end
      end
    end
  end
end

zn.modem = modem

zn.send = function(address, message)
  local hash = hashgen(getTime(), message)
  send(zn.modem.address, address, message, hash, CODES.send, packFlags {})
  return true
end

zn.broadcast = function(message)
  send(zn.modem.address, "", message, nil, CODES.send, packFlags {})
  return true
end

zn.ping = function()
  zn.modem.broadcast(PORT, CODES.ping)
end

math.randomseed(getTime())
modem.open(PORT)
while true do
  local e = {comp.pullSignal()}
  if e[1] == "modem_message" then
    listener(table.unpack(e))
  end
end
