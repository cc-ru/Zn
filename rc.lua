function start()
  local zn = require("zn")
  if not zn.connect() then
    io.stderr:write("Already started\n")
    return 1
  end
  return 0
end

function stop()
  local zn = require("zn")
  zn.disconnect()
end
