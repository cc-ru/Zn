-- ~ Zn ~ 0.1.0 ~
-- Minimalistic p2p network for OpenComputers
--
-- Copyright 2017 Figercomp, Totoro
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


local event = require("event")
local com = require("component")
local computer = require("computer")

local modem = com.modem
local zn = {}

local PORT = 419
local CODES = {
  ping = "Zn/ping",
  send = "Zn/send"
}

-- How long does this node remember transferred message hash (in-game seconds)
-- (Used to kill all possible dublicates)
local HASHLIFETIME = 43200

local isConnected = false


-- Session ---------------------------------------------------------------------

local hashes = {}

local function getTime()
  return tonumber(tostring(os.clock()):gsub("%.",""),10)
end

local function hashgen(time, data)
  return string.char(math.random(0, 255), math.random(0, 255),
                     math.random(0, 255), math.random(0, 255))
end

local function check(hash)
  local time = computer.uptime()
  for k, v in pairs(hashes) do
    if time - v > HASHLIFETIME then
      hashes[k] = nil
    end
  end
  if not hashes[hash] then
    hashes[hash] = computer.uptime()
    return true
  end
  return hashes[hash] == nil
end

local function send(selfAddress, address, message, hash, code)
  local hash = hash or hashgen(getTime(), message)
  hashes[hash] = computer.uptime()
  modem.broadcast(PORT, code, address, selfAddress, hash, message)
  -- print("sent", code, address, selfAddress, hash, message)
end

local function listener(name, receiver, sender, port, distance,
                        code, recvAddr, sendAddr, hash, body)
  -- print("caught", code, recvAddr, sendAddr, hash, body)
  if receiver == zn.modem.address then
    if port == PORT and (code == CODES.send or code == CODES.ping) then
      -- print("prefix&port")
      if check(hash) then
        -- print("checked")
        if recvAddr == zn.modem.address or recvAddr == "" then
          -- print("4me")
          if code == CODES.send then
            -- print("msg4me")
            computer.pushSignal("zn_message", body)
            if recvAddr == receiver then
              send(zn.modem.address, sendAddr, hash, nil, CODES.ping)
            end
          else
            -- print("ping4me")
            computer.pushSignal("zn_pong", body)
          end
        end
        if recvAddr ~= zn.modem.address then
          -- print("not4me")
          send(sendAddr, recvAddr, body, hash, CODES.send)
        end
      end
    end
  end
end

zn.connect = function()
  if isConnected then
    return false
  end
  math.randomseed(getTime())
  modem.open(PORT)
  event.listen("modem_message", listener)
  isConnected = true
  return true
end

zn.disconnect = function()
  if not isConnected then
    return false
  end
  modem.close(PORT)
  event.ignore("modem_message", listener)
  isConnected = false
  return true
end

zn.modem = com.modem

-- Messages --------------------------------------------------------------------

zn.send = function(address, message, timeout)
  timeout = timeout or 5
  local hash = hashgen(getTime(), message)
  send(modem.address, address, message, hash, CODES.send)
  return event.pull(timeout, "zn_pong", hash) == "zn_pong"
end

zn.broadcast = function(message)
  send(modem.address, "", message, nil, CODES.send)
  return true
end

return zn
