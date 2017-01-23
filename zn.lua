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
local PREFIX = "Zn"
local CODES = {
  ping = "Zn/ping",
  send = "Zn/send"
}

-- How long does this node remembers transferred message hash (in-game seconds)
-- (Used to kill all possible dublicates)
local HASHLIFETIME = 43200


-- Session ---------------------------------------------------------------------

local hashes = {}

local function hashgen(time, data)
  return string.char(math.random(0, 255), math.random(0, 255),
                     math.random(0, 255), math.random(0, 255))
end

local function check(hash)
  local time = os.time()
  for k, v in pairs(hashes) do
    if time - v > HASHLIFETIME then
      hashes[k] = nil
    end
  end
  return hashes[hash] == nil
end

local function send(selfAddress, address, message, hash, code)
  local hash = hash or hashgen(os.time(), message)
  hashes[hash] = os.time()
  modem.broadcast(PORT, PREFIX, code, address, selfAddress, hash, message)
end

local function listener(name, receiver, sender, port, distance,
                        prefix, code, recvAddr, sendAddr, hash, body)
  if port == PORT and prefix == PREFIX then
    if check(hash) then
      if recvAddr == receiver or recvAddr == "" then
        if code == CODES.send then
          computer.pushSignal("zn_message", body)
          if recvAddr == receiver then
            send(receiver, sendAddr, hash, nil, CODES.ping)
          end
        else
          computer.pushSignal("zn_pong", body)
        end
      end
      if recvAddr ~= receiver then
        send(receiver, recvAddr, body, hash, CODES.send)
      end
    end
  end
end

zn.connect = function()
  math.randomseed(os.time())
  modem.open(PORT)
  event.listen("modem_message", listener)
end

zn.disconnect = function()
  modem.close(PORT)
  event.ignore("modem_message", listener)
end

-- Messages --------------------------------------------------------------------

zn.send = function(address, message, timeout)
  timeout = timeout or 5
  local hash = hashgen(os.time(), message)
  hashes[hash] = os.time()
  send(modem.address, address, message, hash, CODES.send)
  return event.pull(timeout, "zn_pong", hash) == "zn_pong"
end

zn.broadcast = function(message)
  local hash = hashgen(os.time(), message)
  hashes[hash] = os.time()
  send(modem.address, "", message, hash, CODES.send)
  return true
end

return zn
