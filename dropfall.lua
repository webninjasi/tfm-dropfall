local VERSION = "1.3"
local room = tfm.get.room
local admins = {
  ["Mckeydown#0000"] = true,
  ["Stovedove##0000"] = true,
  ["Lays#1146"] = true,
}
local maps = {
  7955349,
}


local mapName
local bans = {}
local defaultImage

local pressCooldown = {}
local leaderboard = {}
local leaderboardMap = {}
local leaderboardVisible = {}


local function updateImage(targetPlayer, imageId, scaleX, scaleY)
  if imageId then
    tfm.exec.addImage(imageId, "%" .. targetPlayer, 0, 0, nil, scaleX, scaleY, 0, 1, 0.5, 0.5, true)
  end
end

local function preparePlayer(playerName)
  tfm.exec.bindKeyboard(playerName, 46, true, true)
  tfm.exec.bindKeyboard(playerName, 76, true, true)

  local row = leaderboardMap[playerName]
  
  if row then
    tfm.exec.setPlayerScore(playerName, row.hole, false)
  end

  if defaultImage then
    updateImage(playerName, defaultImage.imageId, defaultImage.scaleX, defaultImage.scaleY)
  end
end

local function resetLeaderboard()
  leaderboard = {}
  leaderboardMap = {}
  leaderboardVisible = {}
  ui.removeTextArea(1)

  for playerName in next, room.playerList do
    tfm.exec.setPlayerScore(playerName, 0, false)
  end
end

local function addLeaderboard(playerName, hole, cheese, time)
  local row = leaderboardMap[playerName]

  if row then
    row.hole = row.hole + hole
    row.cheese = row.cheese + cheese

    if time ~= 0 and (row.time == 0 or row.time > time) then
      row.time = time
    end
  else
    row = {
      playerName = playerName,
      hole = hole,
      cheese = cheese,
      time = time,
    }
    leaderboardMap[playerName] = row
    leaderboard[1 + #leaderboard] = row
  end

  tfm.exec.setPlayerScore(playerName, row.hole, false)
  table.sort(leaderboard, function(a, b)
    if a.hole > b.hole then
      return true
    end

    if a.hole == b.hole then
      if a.cheese > b.cheese then
        return true
      end

      if a.cheese == b.cheese then
        return a.time < b.time
      end
    end

    return false
  end)
end

local function hideLeaderboard(playerName)
  leaderboardVisible[playerName] = nil
  ui.removeTextArea(1, playerName)
end

local function showLeaderboard(playerName)
  leaderboardVisible[playerName] = true
  local lines = {
    [0] = '<textformat tabstops="[50,300,350,450]">\n<b>#\tName\tHole\tCheese\tTime</b>\n'
  }
  for i=1, 10 do
    if leaderboard[i] then
      lines[i] = ("<BL>%d\t<V>%s\t<ROSE>%s\t<J>%s\t<CH>%ss"):format(
        i,
        leaderboard[i].playerName,
        leaderboard[i].hole,
        leaderboard[i].cheese,
        leaderboard[i].time / 100
      )
    end
  end
  ui.addTextArea(1, table.concat(lines, '\n', 0, #lines), playerName, 100, 50, 600, 300, 1, 0, 0.8, true)
end


local allowCommandForEveryone = {
  ["version"] = true,
}
local commands
commands = {
  version = function(playerName, args)
    tfm.exec.chatMessage("<BL>#dropfall " .. VERSION, playerName)
  end,

  image = function(playerName, args)
    if args[1] then
      defaultImage = {
        imageId = args[1],
        scaleX = args[2] or 1,
        scaleY = args[3] or 1,
      }

      for targetPlayer in next, room.playerList do
        updateImage(targetPlayer, defaultImage.imageId, defaultImage.scaleX, defaultImage.scaleY)
      end
    else
      defaultImage = nil
    end
  end,

  map = function(playerName, args)
    tfm.exec.newGame(args[1] or maps[math.random(#maps)], args[2])
  end,

  mapname = function(playerName, args)
    if args[1] then
      mapName = args[-1]
      ui.setMapName(mapName)
    else
      mapName = nil
      ui.setMapName("")
    end
  end,

  admin = function(playerName, args)
    if admins[playerName] ~= true then
      return
    end

    if args[1] and not admins[args[1]] then
      admins[args[1]] = 1
    end
  end,

  unadmin = function(playerName, args)
    if admins[playerName] ~= true then
      return
    end

    if args[1] and admins[args[1]] ~= true then
      admins[args[1]] = nil
    end
  end,

  kill = function(playerName, args)
    if args[1] then
      tfm.exec.killPlayer(args[1])
    end
  end,

  respawn = function(playerName, args)
    if args[1] then
      tfm.exec.respawnPlayer(args[1])
    end
  end,

  cheese = function(playerName, args)
    if args[1] then
      tfm.exec.giveCheese(args[1])
    end
  end,

  uncheese = function(playerName, args)
    if args[1] then
      tfm.exec.removeCheese(args[1])
    end
  end,

  win = function(playerName, args)
    if args[1] then
      tfm.exec.giveCheese(args[1])
      tfm.exec.playerVictory(args[1])
    end
  end,

  ban = function(playerName, args)
    if args[1] then
      bans[args[1]] = true
      tfm.exec.killPlayer(args[1])

      if leaderboardMap[args[1]] then
        leaderboardMap[args[1]] = nil

        for i=1, #leaderboard  do
          if leaderboard[i].playerName == args[1] then
            table.remove(leaderboard, i)
            return
          end
        end
      end
    end
  end,

  unban = function(playerName, args)
    if args[1] then
      bans[args[1]] = nil
      tfm.exec.respawnPlayer(args[1])
    end
  end,

  clearleaderboard = function(playerName, args)
    resetLeaderboard()
  end,

  commands = function(playerName, args)
    local list = {}
    for commandName in next, commands do
      list[1 + #list] = commandName
    end

    tfm.exec.chatMessage(table.concat(list, ', '), playerName)
  end,
}


function eventNewGame()
  for playerName in next, room.playerList do
    tfm.exec.freezePlayer(playerName, true, false)

    if bans[playerName] then
      tfm.exec.killPlayer(playerName)
    end
  end

  if mapName then
    ui.setMapName(mapName)
  end
end

function eventPlayerRespawn(playerName)
  tfm.exec.freezePlayer(playerName, true, false)
end

function eventPlayerDied(playerName)
  if not bans[playerName] then
    tfm.exec.respawnPlayer(playerName)
  end
end

function eventPlayerWon(playerName, timeElapsed, timeElapsedSinceRespawn)
  if not bans[playerName] then
    tfm.exec.respawnPlayer(playerName)
    addLeaderboard(playerName, 1, 0, timeElapsedSinceRespawn)
  end
end

function eventPlayerGetCheese(playerName)
  if not bans[playerName] then
    addLeaderboard(playerName, 0, 1, 0)
  end
end

function eventNewPlayer(playerName)
  if not bans[playerName] then
    tfm.exec.respawnPlayer(playerName)
  end

  if mapName then
    ui.setMapName(mapName)
  end

  leaderboardVisible[playerName] = nil
  preparePlayer(playerName)
end

function eventKeyboard(playerName, keyCode)
  if pressCooldown[playerName] and os.time() < pressCooldown[playerName] then
    return
  end

  pressCooldown[playerName] = os.time() + 500

  if keyCode == 46 then
    tfm.exec.killPlayer(playerName)
  elseif keyCode == 76 then
    if leaderboardVisible[playerName] then
      hideLeaderboard(playerName)
    else
      showLeaderboard(playerName)
    end
  end
end

function eventChatCommand(playerName, command)
  local args, count = {}, 0
  for arg in command:gmatch('%S+') do
    args[count] = arg
    count = 1 + count
  end
  args[-1] = command:sub(#args[0] + 1)
  args[0] = args[0]:lower()

  if not admins[playerName] and not allowCommandForEveryone[args[0]] then
    return
  end

  local cmd = commands[args[0]]
  if cmd then
    ok, err = pcall(cmd, playerName, args)
    if err then
      print(("Error on command %s: %s"):format(tostring(args[0]), tostring(err)))
      tfm.exec.chatMessage("<R>An error occured.", playerName)
    end

    if not allowCommandForEveryone[args[0]] then
      for adminName in next, admins do
        tfm.exec.chatMessage(("<CH>[%s] !%s"):format(playerName, command), adminName)
      end
    end
  end
end

for playerName in next, room.playerList do
  preparePlayer(playerName)
end

system.disableChatCommandDisplay(nil, true)

tfm.exec.disablePhysicalConsumables(true)
tfm.exec.disableAfkDeath(true)
tfm.exec.disableAutoShaman(true)
tfm.exec.disableAutoNewGame(true)
tfm.exec.newGame(maps[math.random(#maps)])
