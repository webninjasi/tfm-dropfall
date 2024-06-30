local VERSION = "2.12"
local room = tfm.get.room
local admins = {
  ["Mckeydown#0000"] = true,
  ["Stovedove##0000"] = true,
  ["Lays#1146"] = true,
  ["Inthebin#0000"] = true,
}
local maps = {
  7955349,
  7955436,
}


local mapName
local bans = {}
local defaultImage
local defaultSize
local reloadCode
local fadeInOutEnabled = true
local mapTokenCount = 0

local collectedBonus = {}
local playerImage = {}
local pressCooldown = {}
local leaderboard = {}
local leaderboardMap = {}
local leaderboardVisible = {}


local function checkFadeInOut()
  local count = 0
  for _ in next, room.playerList do
    count = count + 1
  end
  fadeInOutEnabled = count < 20
end

local function updateImage(targetPlayer, imageId, scaleX, scaleY)
  if imageId then
    if playerImage[targetPlayer] then
      tfm.exec.removeImage(playerImage[targetPlayer], fadeInOutEnabled)
      playerImage[targetPlayer] = nil
    end

    playerImage[targetPlayer] = tfm.exec.addImage(imageId, "%" .. targetPlayer, 0, 0, nil, scaleX, scaleY, 0, 1, 0.5, 0.5, fadeInOutEnabled)
  end
end

local function updateScore(playerName, row)
  if mapTokenCount == 0 then
    tfm.exec.setPlayerScore(playerName, row.hole, false)
  else
    local maxChars = #tostring(mapTokenCount)
    tfm.exec.setPlayerScore(playerName, row.hole * math.pow(10, maxChars) + row.currentBonus, false)
  end
end

local function preparePlayer(playerName)
  tfm.exec.bindKeyboard(playerName, 46, true, true)
  tfm.exec.bindKeyboard(playerName, 76, true, true)

  local row = leaderboardMap[playerName]
  if row and mapTokenCount == 0 then
    updateScore(playerName, row)
  end

  if defaultImage then
    updateImage(playerName, defaultImage.imageId, defaultImage.scaleX, defaultImage.scaleY)
  end

  tfm.exec.chatMessage("<BL>[module] <N>Press <J>L <N>for leaderboard", playerName)
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

local function updateLeaderboard(playerName, hole, cheese, time, bonus)
  local row = leaderboardMap[playerName]

  if row then
    row.hole = row.hole + hole
    row.cheese = row.cheese + cheese
    row.timestamp = os.time()
    row.currentBonus = bonus or row.currentBonus

    if bonus and row.bonus < bonus then
      row.bonus = bonus
    end

    if time ~= 0 and (row.time == 0 or row.time > time) then
      row.time = time
    end
  else
    row = {
      playerName = playerName,
      hole = hole or 0,
      cheese = cheese or 0,
      time = time or 0,
      bonus = bonus or 0,
      currentBonus = bonus or 0,
      timestamp = os.time(),
    }
    leaderboardMap[playerName] = row
    leaderboard[1 + #leaderboard] = row
  end

  updateScore(playerName, row)
  table.sort(leaderboard, function(a, b)
    if a.bonus > b.bonus then
      return true
    end

    if a.bonus == b.bonus then
      if a.hole > b.hole then
        return true
      end

      if a.hole == b.hole then
        if a.cheese > b.cheese then
          return true
        end

        if a.cheese == b.cheese then
          if a.time < b.time then
            return true
          end

          if a.time == b.time then
            return a.timestamp < b.timestamp
          end
        end
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
    [0] = '<textformat tabstops="[30,320,400,480,550]">\n<b>#\tName\tTokens\tHole\tCheese\tTime</b>\n'
  }
  local included = false
  for i=1, 10 do
    if leaderboard[i] then
      included = included or leaderboard[i].playerName == playerName
      lines[i] = ("<BL>%d\t<V>%s\t<VP>%s\t<ROSE>%s\t<J>%s\t<CH>%ss"):format(
        i,
        leaderboard[i].playerName,
        leaderboard[i].bonus,
        leaderboard[i].hole,
        leaderboard[i].cheese,
        leaderboard[i].time == 0 and "?" or (leaderboard[i].time / 100)
      )
    end
  end
  local row = leaderboardMap[playerName]
  if row and not included then
    lines[1+#lines] = ("\n<BL>You\t<V>%s\t<VP>%s\t<ROSE>%s\t<J>%s\t<CH>%ss"):format(
      row.playerName,
      row.bonus,
      row.hole,
      row.cheese,
      row.time == 0 and "?" or (leaderboard[i].time / 100)
    )
  end
  lines[1+#lines] = '\n<p align="center"><BL><b>Total Tokens:</b> <N>' .. mapTokenCount
  ui.addTextArea(1, table.concat(lines, '\n', 0, #lines), playerName, 100, 50, 600, 300, 1, 0, 0.8, true)
end


local allowCommandForEveryone = {
  ["version"] = true,
}
local commands
commands = {
  version = function(playerName, args)
    tfm.exec.chatMessage("<BL>[module] <N>dropfall v" .. VERSION, playerName)
  end,

  image = function(playerName, args)
    if args[1] then
      defaultImage = {
        imageId = args[1],
        scaleX = args[2] or 1,
        scaleY = args[3] or args[2] or 1,
      }

      for targetPlayer in next, room.playerList do
        updateImage(targetPlayer, defaultImage.imageId, defaultImage.scaleX, defaultImage.scaleY)
      end
    else
      defaultImage = nil
    end
  end,

  map = function(playerName, args)
    tfm.exec.newGame(args[1] or maps[math.random(1, #maps)], args[2])
  end,

  size = function(playerName, args)
    defaultSize = tonumber(args[1])

    for targetName in next, room.playerList do
      tfm.exec.changePlayerSize(targetName, defaultSize or 1)
    end
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

    tfm.exec.chatMessage('<BL>[module] <N>' .. table.concat(list, ', '), playerName)
  end,
}


function eventNewGame()
  mapTokenCount = 0
  defaultSize = 1

  resetLeaderboard()

  local xml = room.xmlMapInfo and tfm.get.room.xmlMapInfo.xml
  if xml then
    local properties = xml:match('<P (.-)/>')
    if properties then
      local customMapName = properties:match('mapname="(.-)"')
      if customMapName then
        mapName = customMapName
      end

      local customImage = properties:match('image="(.-)"')
      if customImage then
        local imageId, scaleX, scaleY = customImage:match('^(.-),(.-),(.-)$')
        if not imageId then
          imageId, scaleX = customImage:match('^(.-),(.-)$')
        end
        if not imageId then
          imageId = customImage
        end

        defaultImage = {
          imageId = imageId,
          scaleX = tonumber(scaleX) or 1,
          scaleY = tonumber(scaleY) or tonumber(scaleX) or 1,
        }
      end

      if room.xmlMapInfo.author ~= "#Module" and properties:find('reload=""') then
        mapName = ("<J>%s <BL>- @%s"):format(room.xmlMapInfo.author, room.xmlMapInfo.mapCode)
        reloadCode = xml
      end

      if properties:find('defilante="') then
        for obj in xml:gmatch('<O (.-)/>') do
          if obj:find('C="6"') then
            mapTokenCount = mapTokenCount + 1
          end
        end
      end

      local customSize = tonumber(properties:match('size="(%d+)"'))
      if customSize then
        defaultSize = customSize
      end
    end
  end

  for playerName in next, room.playerList do
    tfm.exec.freezePlayer(playerName, true, false)

    if bans[playerName] then
      tfm.exec.killPlayer(playerName)
    end
  end

  if mapName then
    ui.setMapName(mapName)
  end

  collectedBonus = {}
end

function eventLoop(elapsedTime, remainingTime)
  if reloadCode and elapsedTime > 3100 then
    tfm.exec.newGame(reloadCode)
    reloadCode = nil
  end
end

function eventPlayerRespawn(playerName)
  collectedBonus[playerName] = 0
  tfm.exec.freezePlayer(playerName, true, false)

  if defaultImage then
    updateImage(playerName, defaultImage.imageId, defaultImage.scaleX, defaultImage.scaleY)
  end

  if defaultSize then
    tfm.exec.changePlayerSize(playerName, defaultSize)
  end
end

function eventPlayerDied(playerName)
  if not bans[playerName] then
    tfm.exec.respawnPlayer(playerName)
  end
end

function eventPlayerWon(playerName, timeElapsed, timeElapsedSinceRespawn)
  if not bans[playerName] then
    tfm.exec.respawnPlayer(playerName)
    updateLeaderboard(playerName, 1, 0, timeElapsedSinceRespawn)

    tfm.exec.chatMessage(('<BL>[module] <V>%s <N>won the map in <J>%s seconds!'):format(
      playerName,
      timeElapsedSinceRespawn / 100
    ), nil)
  end
end

function eventPlayerGetCheese(playerName)
  if not bans[playerName] then
    updateLeaderboard(playerName, 0, 1, 0)
  end
end

function eventPlayerBonusGrabbed(playerName, bonusId)
  if bans[playerName] or bonusId ~= 0 then
    return
  end

  collectedBonus[playerName] = (collectedBonus[playerName] or 0) + 1
  updateLeaderboard(playerName, 0, 0, 0, collectedBonus[playerName])

  if mapTokenCount == collectedBonus[playerName] then
    tfm.exec.giveCheese(playerName)
    tfm.exec.playerVictory(playerName)
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
  checkFadeInOut()
end

function eventPlayerLeft(playerName)
  checkFadeInOut()
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
      tfm.exec.chatMessage("<BL>[module] <N>An error occured.", playerName)
    end

    if not allowCommandForEveryone[args[0]] then
      for adminName in next, admins do
        tfm.exec.chatMessage(("<V>[%s] <BL>!%s"):format(playerName, command), adminName)
      end
    end
  end
end

for playerName in next, room.playerList do
  preparePlayer(playerName)
end

math.randomseed(os.time())
system.disableChatCommandDisplay(nil, true)
tfm.exec.disablePhysicalConsumables(true)
tfm.exec.disableAfkDeath(true)
tfm.exec.disableAutoShaman(true)
tfm.exec.disableAutoNewGame(true)
tfm.exec.newGame(maps[math.random(1, #maps)])
