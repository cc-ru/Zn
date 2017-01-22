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

-- This is default data for global Zn network
-- You can create local sub-network (not connected with global net),
-- changing port and prefix
local PORT = 419
local PREFIX = "~ZN~"

-- How long does this node remember transferred message hash (in-game seconds)
-- Used to kill all possible dublicates
local HASHLIFETIME = 43200


-- Session ---------------------------------------------------------------------

-- list of last messages hashes
local hashes = {}

local check = function(hash)
  local time = os.time()
  -- clear hashes table
  for k, v in pairs(hashes) do
    if time - v > HASHLIFETIME then hashes[k] = nil end
  end
  -- check
  return hashes[hash] == nil
end

local listener = function(name, receiver, sender, port, distance,
                          prefix, address, hash, body)
  -- check if this is Zn message
  if port == PORT and prefix == PREFIX then
    -- check message hash
    if check(hash) then
      -- check if this message was for us
      if address == receiver or address == "all" then
        -- create event for user
        computer.pushSignal("zn_message", body)
      end
      -- transfer this message, if necessary
      if address ~= receiver then
        zn.send(address, body, hash)
      end
    end
  end
end

zn.connect = function()
  math.randomseed(os.time())
  -- listen to Zn messages
  modem.open(PORT)
  event.listen("modem_message", listener)
end

zn.disconnect = function()
  -- unregister our listener
  modem.close(PORT)
  event.ignore("modem_message", listener)
end


-- Messages --------------------------------------------------------------------

-- fake but fast =)
local hashgen = function(data)
  return math.random()
end

zn.send = function(address, message, hash)
  local hash = hash or hashgen(message)
  -- remember our hash (we don't want to get our message back)
  hashes[hash] = os.time()
  -- send message
  modem.broadcast(PORT, PREFIX, address, hash, message)
end

zn.broadcast = function(message, hash)
  zn.send("all", message, hash)
end

return zn
