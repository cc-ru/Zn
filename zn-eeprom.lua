local com = component
local comp = computer

local modem = com.proxy(com.list("modem")())
local zn = {}

local PORT = 419
local CODES = {
  ack = "Zn/ack",
  send = "Zn/send",
  ping = "Zn/ping",
  pong = "Zn/pong"
}

local FLAGS = {
  ACK = "\x50"
}

local HASHLIFETIME = 43200
local isConnected = false

local hashes = {}

local function getTime()
  return tonumber(tostring(os.clock()):gsub("%.",""),10)
end

local function hashgen(time, data)
  return string.char(math.random(0, 255), math.random(0, 255),
                     math.random(0, 255), math.random(0, 255))
end

local function check(hash)
  local time = comp.uptime()
  for k, v in pairs(hashes) do
    if time - v > HASHLIFETIME then
      hashes[k] = nil
    end
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
  modem.broadcast(PORT, code, address, selfAddress, hash, flags, message)
end

local function listener(name, receiver, sender, port, distance,
                        code, recvAddr, sendAddr, hash, flags, body)
  if receiver == zn.modem.address then
    if port == PORT and (
        code == CODES.send or
        code == CODES.pong or
        code == CODES.ping or
        code == CODES.ack) then
      if code == CODES.ping then
        comp.pushSignal("zn_ping", sender, distance)
        modem.send(sender, PORT, CODES.pong)
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
            if recvAddr == receiver and parseFlags(flags).ACK then
              send(zn.modem.address, sendAddr, hash, nil, CODES.ack, packFlags {})
            end
          elseif code == CODES.ack then
            comp.pushSignal("zn_ack", body, recvAddr, sendAddr)
          end
        end
        if recvAddr ~= zn.modem.address then
          send(sendAddr, recvAddr, body, hash, CODES.send, flags)
        end
      end
    end
  end
end

zn.modem = com.modem

zn.send = function(address, message, timeout)
  local flags = {ACK = true}
  if timeout == nil then
    timeout = 5
  elseif timeout == false then
    flags.ACK = nil
  end
  local hash = hashgen(getTime(), message)
  send(modem.address, address, message, hash, CODES.send, packFlags(flags))
  if timeout == false then
    return true
  end
  return event.pull(timeout, "zn_ack", hash) == "zn_ack"
end

zn.broadcast = function(message)
  send(modem.address, "", message, nil, CODES.send, packFlags {})
  return true
end

zn.ping = function()
  modem.broadcast(PORT, CODES.ping)
end

math.randomseed(getTime())
modem.open(PORT)
while true do
  local e = {comp.pullSignal()}
  if e[1] == "modem_message" then
    listener(table.unpack(e))
  end
end