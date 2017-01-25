# Zn
A minimalistic OpenComputers decentralized unstructured network.

All Zn traffic is transferred by nodes of network.
The library dispatches messages, and generates events for messages addressed to
a specific node or broadcast to all nodes.

The network structure can be changed dynamically.

It uses port `419` for communication.

Zn network provides "network layer" according to
[OSI model](https://en.wikipedia.org/wiki/OSI_model).
On top of it you can build your transport protocol similar to TCP/UDP, etc.

## Installation
Run this command from terminal:

```
hpm install zn
```

The EEPROM version is also bundled with the package, stored in
`/usr/share/zn/eeprom.lua`.

Flash it using the `flash` utility included in OpenOS.

## Functions
* `zn.connect():boolean`

Registers Zn network listener. This makes a computer a node of Zn network,
so it can send and receive network messages.

* `zn.send(address: string, message: string, [timeout: boolean/number]):boolean`

Sends the `message` to `address` (modem address of a node).

You can set the timeout of acknowledgement, measured in seconds, to arbitrary
number, or `false` to disable acknowledgement at all for this message.

This function returns `true` if no acknowledgement is requested, or the
receiving node sent an ACK message signalling that it has received the message.

* `zn.ping()`

Sends the ping message to neighbors. The message won't be relayed to other
nodes. Fires `zn_pong` events for each pong message received.

* `zn.broadcast(message: string):boolean`

The same as `zn.send`, but the message will be delivered to all nodes.

* `zn.disconnect():boolean`

Disconnects from the network.

## Events

* `zn_message(message: string, receiverAddr: string, senderAddr: string)`

The client has received a Zn message.

* `zn_ack(hash: string, receiverAddr: string, senderAddr: string)`

An acknowledgement for some message has been received.

* `zn_ping(senderAddr: string, distance: number)`

A ping request has been received.

* `zn_pong(senderAddr: string, distance: number)`

A response to the ping message has been received.

## Example
```lua
local event = require('event')
local zn = require('zn')

zn.connect()

zn.broadcast("Hello Zn members!")

while true do
  local _, message = event.pull("zn_message")
  if message == "bye" then
    break
  else
    print(message)
  end
end

zn.disconnect()
```
