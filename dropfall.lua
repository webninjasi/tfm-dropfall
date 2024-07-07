local VERSION = "3.45"
local MODULE_ROOM = "*#mckeydown dropfall %s"
local room = tfm.get.room
local admins = {
  ["Mckeydown#0000"] = 10,
  ["Lays#1146"] = 10,
  ["Stovedove##0000"] = 7,
  ["Inthebin#0000"] = 7,
}
local maps = {
  7955349,
  7955436,
  7955494,
  7955497,
  7955501,
  7955503,
  7955511,
  7955571,
  7955647,
  7955669,
}


local loadMapCode, loadMapReversed
do
  local nextLoadTime
  local newGame = tfm.exec.newGame

  function tfm.exec.newGame(mapCode, flipped)
    if nextLoadTime and os.time() < nextLoadTime then
      loadMapCode, loadMapReversed = mapCode, flipped
      return
    end

    nextLoadTime = os.time() + 3100
    loadMapCode, loadMapReversed = nil, nil
    newGame(mapCode, flipped)
  end
end


local backgroundColor
local specX, specY
local defaultGrav, defaultWind = 10, 0
local mapGravity, mapWind = 10, 0
local mapName
local lastMapCode
local mapTeleports
local bans = {}
local defaultImage
local defaultSize
local fadeInOutEnabled = true
local mapTokenCount = 0
local mapCheckpoints, checkpointImage, checkpointImageSX, checkpointImageSY
local teleportReplace
local teleportTime
local mapBoosters
local meepEnabled

local playerCp
local roomPlayers = {}
local spectator = {}
local cpImage = {}
local collectedBonus = {}
local playerImage = {}
local pressCooldown = {}
local leaderboard = {}
local leaderboardMap = {}
local leaderboardVisible = {}


local function parseXMLAttr(str, name)
  return str:match(' ' .. name .. '="(.-)"')
end

local function parseXMLArray(str, max)
  local list, count = {}, 0
  if str then
    for value in str:gmatch('[^,]+') do
      count = 1 + count
      list[count] = value
      if count == max then
        break
      end
    end
  end
  return list
end

local function parseXMLNumArray(str, max)
  local list = parseXMLArray(str, max)
  for i=1, #list do
    list[i] = tonumber(list[i])
  end
  return list
end

local function parseXMLNumAttr(str, name, max)
  return table.unpack(parseXMLNumArray(parseXMLAttr(str, name), max))
end

local function disableStuff()
  system.disableChatCommandDisplay(nil, true)
  tfm.exec.disablePhysicalConsumables(true)
  tfm.exec.disableAfkDeath(true)
  tfm.exec.disableAutoShaman(true)
  tfm.exec.disableAutoNewGame(true)
end

local function sendModuleMessage(text, playerName)
  tfm.exec.chatMessage("<BL>[module] <N>" .. tostring(text), playerName)
end

local function announceAdmins(message)
  for adminName in next, admins do
    if roomPlayers[adminName] then
      tfm.exec.chatMessage(message, adminName)
    end
  end
end

local function placeTeleport(playerName, tp, initial)
  if not tp then
    return
  end

  tfm.exec.removeBonus(100+tp.index, playerName)
  tfm.exec.addBonus(0, tp.x1, tp.y1, 100+tp.index, 0, false, playerName)

  if initial then
    tfm.exec.addImage("17948dad4f5.png", "_444", tp.x1, tp.y1, playerName, 1, 1, 0, 1, 0.5, 0.5, false)
  end
end

local function placeCheckpoint(playerName, index)
  if not mapCheckpoints then
    return
  end

  local cp = mapCheckpoints[index]
  if not cp then
    return
  end

  tfm.exec.removeBonus(4, playerName)
  tfm.exec.addBonus(0, cp.X, cp.Y, 4, 0, not checkpointImage, playerName)

  if checkpointImage then
    if cpImage[playerName] then
      tfm.exec.removeImage(cpImage[playerName])
    end

    cpImage[playerName] = tfm.exec.addImage(checkpointImage, "!444", cp.X, cp.Y, playerName, checkpointImageSX, checkpointImageSY, 0, 1, 0.5, 0.5, false)
  end
end

local function checkFadeInOut()
  local count = 0
  for _ in next, roomPlayers do
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
  if mapTokenCount == 0 and not mapCheckpoints then
    tfm.exec.setPlayerScore(playerName, row.hole, false)
  else
    local maxChars = #tostring(mapTokenCount)
    tfm.exec.setPlayerScore(playerName, row.hole * math.pow(10, maxChars) + row.currentBonus, false)
  end
end

local function initPlayer(playerName)
  roomPlayers[playerName] = true

  tfm.exec.bindKeyboard(playerName, 46, true, true)
  tfm.exec.bindKeyboard(playerName, 76, true, true)

  local row = leaderboardMap[playerName]
  if row and mapTokenCount == 0 then
    updateScore(playerName, row)
  end

  if defaultImage then
    updateImage(playerName, defaultImage.imageId, defaultImage.scaleX, defaultImage.scaleY)
  end

  tfm.exec.chatMessage("<BL>[module] <N>You can type <G>!help <N>to see a help message and press <J>L <N>for the leaderboard", playerName)

  local player = room.playerList[playerName]
  local tribeName = room.name:sub(3)
  local isGuest = playerName:find('*')

  if not isGuest and player then
    if room.name:find(playerName) or room.isTribeHouse and player.tribeName == tribeName then
      admins[playerName] = 6
    end
  end

  if not admins[playerName] then
    eventChatCommand(playerName, 'room onlymine')
  end
end

local function resetLeaderboard()
  leaderboard = {}
  leaderboardMap = {}
  leaderboardVisible = {}
  ui.removeTextArea(1)

  for playerName in next, roomPlayers do
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

    if hole > 0 then
      row.bonus = bonus or 0
    else
      if bonus and row.bonus < bonus then
        row.bonus = bonus
      end
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
    if a.hole > b.hole then
      return true
    end

    if a.hole == b.hole then
      if a.bonus > b.bonus then
        return true
      end

      if a.bonus == b.bonus then
        if a.currentBonus > b.currentBonus then
          return true
        end

        if a.currentBonus == b.currentBonus then
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
    [0] = ('<textformat tabstops="[30,270,360,430,500]">\n<b>#\tName\tHole\t%s\tCheese\tTime</b>\n'):format(
      mapCheckpoints and "Checkpoints" or "Tokens"
    )
  }
  local included = false
  for i=1, 10 do
    if leaderboard[i] then
      included = included or leaderboard[i].playerName == playerName
      lines[i] = ("<BL>%d\t<V>%s\t<ROSE>%s\t<VP>%s\t<J>%s\t<CH>%ss"):format(
        i,
        leaderboard[i].playerName,
        leaderboard[i].hole,
        leaderboard[i].bonus,
        leaderboard[i].cheese,
        leaderboard[i].time == 0 and "?" or (leaderboard[i].time / 100)
      )
    end
  end
  local row = leaderboardMap[playerName]
  if row and not included then
    lines[1+#lines] = ("\n<BL>You\t<V>%s\t<ROSE>%s\t<VP>%s\t<J>%s\t<CH>%ss"):format(
      row.playerName,
      row.hole,
      row.bonus,
      row.cheese,
      row.time == 0 and "?" or (row.time / 100)
    )
  end
  if mapTokenCount ~= 0 then
    lines[1+#lines] = '\n<p align="center"><BL><b>Total Tokens:</b> <N>' .. mapTokenCount
  end
  if mapCheckpoints then
    lines[1+#lines] = '\n<p align="center"><BL><b>Total Checkpoints:</b> <N>' .. #mapCheckpoints
  end
  ui.addTextArea(1, table.concat(lines, '\n', 0, #lines), playerName, 100, 50, 600, 300, 1, 0, 0.8, true)
end


local allowCommandForEveryone = {
  ["version"] = true,
  ["mapinfo"] = true,
  ["commands"] = true,
  ["help"] = true,
  ["spec"] = true,
  ["room"] = true,
}
local commands
commands = {
  spec = function(playerName, args)
    spectator[playerName] = not spectator[playerName]

    if room.playerList[playerName] and room.playerList[playerName].isDead then
      if not bans[playerName] and not spectator[playerName] then
        tfm.exec.respawnPlayer(playerName)
      end
      return
    end
  
    tfm.exec.killPlayer(playerName)
  end,

  speczone = function(playerName, args)
    specX, specY = tonumber(args[1]), tonumber(args[2])
  end,

  help = function(playerName, args)
    tfm.exec.chatMessage("<BL>[module] <N>You can AFK here I guess, type <G>!commands <N>for more useful commands. Also press <J>L <N>for leaderboard!", playerName)
  end,

  mapinfo = function(playerName, args)
    tfm.exec.chatMessage("<BL>[module] <N>" .. tostring(lastMapCode), playerName)
  end,

  version = function(playerName, args)
    tfm.exec.chatMessage("<BL>[module] <N>dropfall v" .. VERSION  .. ' ~ Lays#1146', playerName)
  end,

  admins = function(playerName, args)
    local list = {}
    for name in next, admins do
      list[1 + #list] = name
    end
    tfm.exec.chatMessage("<BL>[module] <N>admins:", playerName)
    for i=1, #list, 10 do
      tfm.exec.chatMessage("<V>" .. table.concat(list, ' ', i, math.min(#list, i+9)), playerName)
    end
    return true
  end,

  image = function(playerName, args)
    if args[1] then
      defaultImage = {
        imageId = args[1],
        scaleX = args[2] or 1,
        scaleY = args[3] or args[2] or 1,
      }

      for targetPlayer in next, roomPlayers do
        updateImage(targetPlayer, defaultImage.imageId, defaultImage.scaleX, defaultImage.scaleY)
      end
    else
      defaultImage = nil
    end
  end,

  map = function(playerName, args)
    tfm.exec.newGame(args[1] or maps[math.random(1, #maps)], args[2])
  end,

  rst = function(playerName, args)
    if room.currentMap == "@0" then
      if room.xmlMapInfo.xml then
        tfm.exec.newGame(room.xmlMapInfo.xml, args[1])
      end
    else
      tfm.exec.newGame(room.currentMap, args[1])
    end
  end,

  size = function(playerName, args)
    defaultSize = tonumber(args[1])

    for targetName in next, roomPlayers do
      tfm.exec.changePlayerSize(targetName, defaultSize or 1)
    end
  end,

  boost = function(playerName, args)
    if not args[1] then
      tfm.exec.chatMessage('<BL>[module] <N>Boosters on the map: <G>(vx, vy, wind, gravity, power, radius, miceOnly)', playerName)
      if not mapBoosters then
        return true
      end

      for id, booster in next, mapBoosters do
        tfm.exec.chatMessage(('  <V>%s<N>: %s %s %s %s %s %s %s'):format(
          id,
          tostring(booster.vx),
          tostring(booster.vy),
          tostring(booster.wind),
          tostring(booster.gravity),
          tostring(booster.power),
          tostring(booster.radius),
          tostring(booster.miceOnly)
        ), playerName)
      end
      return true
    end

    local id = tonumber(args[1])
    if not id then
      return true
    end

    local booster = mapBoosters and mapBoosters[id]
    if not args[2] then
      if not booster then
        tfm.exec.chatMessage(('<BL>[module] <N>Booster <V>%s <N>doesn\'t exist'):format(
          id
        ), playerName)
        return true
      end

      tfm.exec.chatMessage(('<BL>[module] <N>Booster <V>%s<N>: %s %s %s %s %s %s %s <G>(vx, vy, wind, gravity, power, radius, miceOnly)'):format(
        id,
        tostring(booster.vx),
        tostring(booster.vy),
        tostring(booster.wind),
        tostring(booster.gravity),
        tostring(booster.power),
        tostring(booster.radius),
        tostring(booster.miceOnly)
      ), playerName)
      return true
    end

    if not booster then
      booster = {}
      mapBoosters = mapBoosters or {}
      mapBoosters[id] = booster
    end

    booster.vx = tonumber(args[2]) or booster.vx
    booster.vy = tonumber(args[3]) or booster.vy
    booster.wind = tonumber(args[4]) or booster.wind
    booster.gravity = tonumber(args[5]) or booster.gravity
    booster.power = tonumber(args[6]) or booster.power
    booster.radius = tonumber(args[7]) or booster.radius
    if args[8] then
      booster.miceOnly = tonumber(args[8]) == 1
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

  bgcolor = function(playerName, args)
    backgroundColor = args[1] and ("#" .. args[1]) or nil
    ui.setBackgroundColor(backgroundColor)
  end,

  grav = function(playerName, args)
    mapWind = tonumber(args[2]) or defaultWind
    mapGravity = tonumber(args[1]) or defaultGrav
    tfm.exec.setWorldGravity(mapWind, mapGravity)
  end,

  admin = function(playerName, args)
    local targetName = args[1]
    if not targetName then
      return
    end

    if admins[targetName] and admins[targetName] >= admins[playerName] then
      return
    end

    admins[targetName] = 5
  end,

  unadmin = function(playerName, args)
    local targetName = args[1]
    if not targetName then
      return
    end

    if admins[targetName] and admins[targetName] >= admins[playerName] then
      return
    end

    admins[targetName] = nil
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

    if admins[playerName] then
      for commandName in next, commands do
        list[1 + #list] = commandName
      end
    else
      for commandName in next, allowCommandForEveryone do
        list[1 + #list] = commandName
      end
    end

    table.sort(list)
    sendModuleMessage('Available commands: <BL>' .. table.concat(list, ', '), playerName)
  end,
}

commands.room = function(playerName, args)
  sendModuleMessage("You can create your room by typing\n<BL>/room " .. MODULE_ROOM:format(playerName), playerName)

  if args[1] ~= 'onlymine' then
    local roomName = tfm.get.room.name

    if roomName:sub(1, 1) ~= '@' and roomName:sub(1, 1) ~= '*' then
      roomName = ('%s <J>(%s)'):format(roomName, tfm.get.room.community)
    end

    sendModuleMessage("You are currently in\n<BL>/room " .. roomName, playerName)
  end
end

commands.meep = function(playerName, args)
  meepEnabled = not meepEnabled

  for name in next, roomPlayers do
    tfm.exec.giveMeep(name, meepEnabled)
  end
end


function eventNewGame()
  disableStuff()

  specX, specY = nil, nil
  defaultGrav, defaultWind = 10, 0
  mapGravity, mapWind = defaultGrav, defaultWind
  mapTokenCount = 0
  defaultSize = 1
  mapCheckpoints = nil
  playerCp = nil
  mapTeleports = nil
  defaultImage = nil
  teleportReplace = nil
  teleportTime = nil
  mapBoosters = nil
  meepEnabled = false

  if room.currentMap ~= "@0" and lastMapCode ~= room.currentMap then
    resetLeaderboard()
    mapName = nil
    lastMapCode = room.currentMap
  end

  local xml = room.xmlMapInfo and tfm.get.room.xmlMapInfo.xml
  if xml then
    local properties = xml:match('<P( .-)/>')
    if properties then
      if room.xmlMapInfo.author ~= "#Module" and properties:find('reload=""') then
        mapName = ("<J>%s <BL>- @%s"):format(room.xmlMapInfo.author, room.xmlMapInfo.mapCode)
        tfm.exec.newGame(xml)
      else
        defaultWind, defaultGrav = parseXMLNumAttr(properties, 'G', 2)
        defaultWind = defaultWind or 0
        defaultGrav = defaultGrav or 10
        mapGravity, mapWind = defaultGrav, defaultWind

        specX, specY = parseXMLNumAttr(properties, 'speczone', 2)

        local customMapName = parseXMLAttr(properties, 'mapname')
        if customMapName then
          mapName = customMapName
        end

        local customImage = parseXMLAttr(properties, 'image')
        if customImage then
          local imageId, scaleX, scaleY = table.unpack(parseXMLArray(customImage, 3))
          if imageId then
            defaultImage = {
              imageId = imageId,
              scaleX = tonumber(scaleX) or 1,
              scaleY = tonumber(scaleY) or tonumber(scaleX) or 1,
            }
          end
        end

        if properties:find(' defilante="') then
          for obj in xml:gmatch('<O (.-)/>') do
            if obj:find('C="6"') then
              mapTokenCount = mapTokenCount + 1
            end
          end
        end

        if properties:find(' meep=""') then
          meepEnabled = true
        end

        backgroundColor = parseXMLAttr(properties, 'bgcolor') or backgroundColor
        ui.setBackgroundColor(backgroundColor)

        if properties:find(' kitchensink="') then
          local checkpoints = {}
          local objType, objX, objX

          for obj in xml:gmatch('<O( .-)/>') do
            objType = parseXMLNumAttr(obj, 'C', 1)
            objX = parseXMLNumAttr(obj, 'X', 1)
            objY = parseXMLNumAttr(obj, 'Y', 1)
            if objType == 22 and objX and objY then
              checkpoints[1+#checkpoints] = {
                X = objX,
                Y = objY,
              }
            end
          end

          if #checkpoints > 0 then
            mapCheckpoints = checkpoints
            checkpointImage, checkpointImageSX, checkpointImageSY = table.unpack(parseXMLArray(parseXMLAttr(properties, 'kitchensink'), 3))
            checkpointImageSX = tonumber(checkpointImageSX)
            checkpointImageSY = tonumber(checkpointImageSY)
            playerCp = {}
          end
        end

        local tp = {}
        local x1, y1, x2, y2, vx, vy
        local relative
        local index = 0
        for joint in xml:gmatch('<JD( .-)/>') do
          if joint:find(' tp="') then
            x1, y1 = parseXMLNumAttr(joint, 'P1', 2)
            x2, y2 = parseXMLNumAttr(joint, 'P2', 2)
            vx, vy, relative = parseXMLNumAttr(joint, 'tp', 3)
            index = 1 + index
            tp[index] = {
              x1 = tonumber(x1) or 0,
              y1 = tonumber(y1) or 0,
              x2 = tonumber(x2) or 0,
              y2 = tonumber(y2) or 0,
              vx = tonumber(vx) or 0,
              vy = tonumber(vy) or 0,
              relative = relative == 1,
              index = index,
            }
          end
        end

        if #tp > 0 then
          mapTeleports = tp
          teleportTime = {}
        end

        local groundX, groundY, booster
        local contactId, velX, velY, accX, accY
        local power, radius, miceOnly
        for ground in xml:gmatch('<S( [^>]*contact="%d+"[^>]*)/>') do
          contactId = parseXMLNumAttr(ground, 'contact', 1)
          if contactId then
            groundX = parseXMLNumAttr(ground, 'X', 1)
            groundY = parseXMLNumAttr(ground, 'Y', 1)

            if not mapBoosters then
              mapBoosters = {}
            end

            booster = {
              x = groundX or 0,
              y = groundY or 0,
            }
            mapBoosters[contactId] = booster

            velX, velY, accX, accY = parseXMLNumAttr(ground, 'boost', 4)
            velX = velX or 0
            velY = velY or 0
            if velX ~= 0 or velY ~= 0 or accX or accY then
              booster.vx = velX
              booster.vy = velY
              booster.wind = accX
              booster.gravity = accY
            end

            accY, accX = parseXMLNumAttr(ground, 'gwscale', 2)
            if accX or accY then
              booster.wind = accX and (accX * (mapWind == 0 and 0.01 or mapWind)) or nil
              booster.gravity = accY and (accY * (mapGravity == 0 and 0.01 or mapGravity)) or nil
            end

            power, radius, miceOnly = parseXMLNumAttr(ground, 'explosion', 3)
            if power then
              booster.power = power
              booster.radius = radius
              booster.miceOnly = miceOnly == 1
            end
          end
        end

        local customSize = tonumber(properties:match('size="(%d+)"'))
        if customSize then
          defaultSize = customSize
        end
      end
    end
  end

  collectedBonus = {}

  for playerName in next, roomPlayers do
    if mapTeleports then
      for i=1, #mapTeleports do
        placeTeleport(playerName, mapTeleports[i], true)
      end
    end
  
    if bans[playerName] or spectator[playerName] and not (specX and specY) then
      tfm.exec.killPlayer(playerName)
    else
      eventPlayerRespawn(playerName)
    end

    tfm.exec.giveMeep(playerName, meepEnabled)
  end

  if mapName then
    ui.setMapName(mapName)
  end
end

function eventLoop(elapsedTime, remainingTime)
  if loadMapCode then
    tfm.exec.newGame(loadMapCode, loadMapReversed)
  end

  if teleportReplace and mapTeleports then
    for playerName, teleports in next, teleportReplace do
      for index in next, teleports do
        placeTeleport(playerName, mapTeleports[index], false)
      end
    end

    teleportReplace = nil
  end
end

function eventPlayerRespawn(playerName)
  if spectator[playerName] then
    if specX and specY then
      tfm.exec.movePlayer(playerName, specX, specY)
    end

    return
  end

  collectedBonus[playerName] = 0
  tfm.exec.freezePlayer(playerName, true, false)

  if mapCheckpoints then
    playerCp[playerName] = nil
    placeCheckpoint(playerName, 1)
  end

  if defaultImage then
    updateImage(playerName, defaultImage.imageId, defaultImage.scaleX, defaultImage.scaleY)
  end

  if defaultSize then
    tfm.exec.changePlayerSize(playerName, defaultSize)
  end

  tfm.exec.giveMeep(playerName, false)
  tfm.exec.giveMeep(playerName, meepEnabled)
end

function eventPlayerDied(playerName)
  if loadMapCode then
    return
  end
  if not bans[playerName] and (not spectator[playerName] or specX and specY) then
    tfm.exec.respawnPlayer(playerName)
  end
end

function eventPlayerWon(playerName, timeElapsed, timeElapsedSinceRespawn)
  if loadMapCode then
    return
  end
  if not bans[playerName] then
    if not spectator[playerName] or specX and specY then
      tfm.exec.respawnPlayer(playerName)
    end

    if spectator[playerName] then
      return
    end

    updateLeaderboard(playerName, 1, 0, timeElapsedSinceRespawn)

    tfm.exec.chatMessage(('<BL>[module] <V>%s <N>has won the map in <J>%s seconds!'):format(
      playerName,
      timeElapsedSinceRespawn / 100
    ), nil)
  end
end

function eventPlayerGetCheese(playerName)
  if spectator[playerName] then
    return
  end

  if not bans[playerName] then
    updateLeaderboard(playerName, 0, 1, 0)
  end
end

function eventContactListener(playerName, groundId, info)
  if not mapBoosters or spectator[playerName] then
    return
  end

  local booster = mapBoosters[tonumber(groundId)]
  if not booster then
    return
  end

  if booster.vx or booster.vy then
    tfm.exec.movePlayer(playerName, 0, 0, true, booster.vx or 0, booster.vy or 0, true)
  end

  if booster.gravity or booster.wind then
    local grav = booster.gravity and (booster.gravity / (mapGravity == 0 and 0.01 or mapGravity)) or 1
    local wind = booster.wind and (booster.wind / (mapWind == 0 and 0.01 or mapWind)) or 1
    tfm.exec.setPlayerGravityScale(playerName, grav, wind)
  end

  if booster.power then
    tfm.exec.explosion(info.contactX, info.contactY, booster.power, booster.radius, booster.miceOnly)
  end
end

function eventPlayerBonusGrabbed(playerName, bonusId)
  if mapTeleports and bonusId >= 100 then
    local tp = mapTeleports[bonusId - 100]
    if tp then
      if not bans[playerName] and not spectator[playerName] then
        tfm.exec.movePlayer(playerName, tp.x2, tp.y2, false, tp.vx, tp.vy, tp.relative)
      end

      if teleportTime[playerName] and os.time() < teleportTime[playerName] then
        if not teleportReplace then
          teleportReplace = {}
        end
  
        if not teleportReplace[playerName] then
          teleportReplace[playerName] = {}
        end
  
        teleportReplace[playerName][tp.index] = true
        return
      end

      teleportTime[playerName] = os.time() + 1000
      placeTeleport(playerName, tp, false)
    end
    return
  end

  if bans[playerName] or spectator[playerName] then
    return
  end

  if mapCheckpoints then
    if bonusId == 4 then
      updateLeaderboard(playerName, 0, 0, 0, playerCp[playerName] or 1)
      playerCp[playerName] = (playerCp[playerName] or 1) + 1
      if playerCp[playerName] > #mapCheckpoints then
        playerCp[playerName] = nil
        tfm.exec.giveCheese(playerName)
        tfm.exec.playerVictory(playerName)
        return
      end
      placeCheckpoint(playerName, playerCp[playerName])
    end
    return
  end

  if bonusId ~= 0 then
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
  initPlayer(playerName)

  if backgroundColor then
    ui.setBackgroundColor(backgroundColor)
  end

  if not bans[playerName] and (not spectator[playerName] or specX and specY) then
    tfm.exec.respawnPlayer(playerName)
  end

  if mapName then
    ui.setMapName(mapName)
  end

  if mapTeleports then
    for i=1, #mapTeleports do
      placeTeleport(playerName, mapTeleports[i], true)
    end
  end

  checkFadeInOut()
end

function eventPlayerLeft(playerName)
  roomPlayers[playerName] = nil
  leaderboardVisible[playerName] = nil
  collectedBonus[playerName] = nil
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
  args[-1] = command:sub(#args[0] + 2)
  args[0] = args[0]:lower()

  if not admins[playerName] and not allowCommandForEveryone[args[0]] then
    return
  end

  local cmd = commands[args[0]]
  if cmd then
    ok, err = pcall(cmd, playerName, args)
    if not ok and err then
      sendModuleMessage(("<R>Module error on command !%s: <BL>%s"):format(args[0], tostring(err)), playerName)
    end

    if not allowCommandForEveryone[args[0]] and (ok and not err) then
      announceAdmins(("<V>[%s] <BL>!%s"):format(playerName, command))
    end
  end
end


for eventName, eventFunc in next, _G do
  if eventName:find('event') == 1 then
    _G[eventName] = function(...)
      ok, err = pcall(eventFunc, ...)
      if not ok then
        announceAdmins(("<R>Module error on %s: <BL>%s"):format(eventName, tostring(err)))
      end
    end
  end
end

for playerName in next, room.playerList do
  initPlayer(playerName)
end

math.randomseed(os.time())
disableStuff()
tfm.exec.newGame(maps[math.random(1, #maps)])
