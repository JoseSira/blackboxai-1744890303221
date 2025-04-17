--[[
    Aviator Game Logic
    Author: BLACKBOXAI
    Description: Implementación del juego Aviator para el sistema de casino.
    Un juego de crash betting donde el multiplicador aumenta hasta que el avión se estrella.
]]

-- Importar configuración
local config = exports.casino_config

-- Variables locales
local activeGames = {}
local activeRound = nil
local roundTimer = nil
local updateTimer = nil

-- Clase para manejar una ronda de Aviator
local AviatorRound = {
    players = {},          -- Jugadores en la ronda actual
    multiplier = 1.0,      -- Multiplicador actual
    status = "waiting",    -- waiting, flying, crashed
    startTime = 0,         -- Tiempo de inicio
    crashPoint = 1.0,      -- Punto donde crasheará
    lastUpdate = 0,        -- Último tiempo de actualización
    pattern = nil          -- Patrón de crash seleccionado
}

function AviatorRound:new()
    local round = {
        players = {},
        multiplier = 1.0,
        status = "waiting",
        startTime = 0,
        crashPoint = 1.0,
        lastUpdate = 0,
        pattern = nil
    }
    setmetatable(round, {__index = self})
    return round
end

function AviatorRound:initialize()
    -- Seleccionar patrón de crash basado en probabilidades
    self.pattern = self:selectPattern()
    
    -- Calcular punto de crash basado en el patrón
    self.crashPoint = self:calculateCrashPoint()
    
    -- Inicializar temporizadores
    self.startTime = getTickCount()
    self.lastUpdate = self.startTime
    
    self.status = "flying"
    return true
end

function AviatorRound:selectPattern()
    local patterns = config.getConfig("aviator", "patterns")
    local random = math.random()
    local cumulativeProbability = 0
    
    for name, pattern in pairs(patterns) do
        cumulativeProbability = cumulativeProbability + pattern.probability
        if random <= cumulativeProbability then
            return {
                name = name,
                min = pattern.min,
                max = pattern.max
            }
        end
    end
    
    -- Patrón por defecto si algo falla
    return {
        name = "medium",
        min = patterns.medium.min,
        max = patterns.medium.max
    }
end

function AviatorRound:calculateCrashPoint()
    -- Usar el patrón seleccionado para determinar el punto de crash
    local point = self.pattern.min + (math.random() * (self.pattern.max - self.pattern.min))
    
    -- Ajustar según la probabilidad de victoria configurada
    local maxWinProb = config.getConfig("aviator", "maxWinProbability")
    if math.random() > maxWinProb then
        point = math.min(point, 2.0) -- Forzar crash temprano si supera la probabilidad
    end
    
    return point
end

function AviatorRound:update()
    if self.status ~= "flying" then return end
    
    local currentTime = getTickCount()
    local elapsed = (currentTime - self.startTime) / 1000
    local speed = config.getConfig("aviator", "multiplierSpeed")
    
    -- Calcular nuevo multiplicador
    self.multiplier = 1.0 + (elapsed * speed)
    
    -- Verificar si alcanzó el punto de crash
    if self.multiplier >= self.crashPoint then
        self:crash()
        return
    end
    
    -- Notificar a todos los jugadores activos
    self:broadcastUpdate()
end

function AviatorRound:crash()
    self.status = "crashed"
    
    -- Procesar pérdidas para jugadores que no hicieron cash out
    for _, player in pairs(self.players) do
        if not player.cashedOut then
            exports.casino:processLoss(player.element)
        end
    end
    
    -- Notificar crash a todos los jugadores
    self:broadcastCrash()
    
    -- Programar nueva ronda
    setTimer(startNewRound, 3000, 1)
end

function AviatorRound:broadcastUpdate()
    local state = self:getState()
    for _, player in pairs(self.players) do
        triggerClientEvent(player.element, "onAviatorUpdate", resourceRoot, state)
    end
end

function AviatorRound:broadcastCrash()
    local state = self:getState()
    for _, player in pairs(self.players) do
        triggerClientEvent(player.element, "onAviatorCrash", resourceRoot, state)
    end
end

function AviatorRound:getState()
    return {
        multiplier = self.multiplier,
        status = self.status,
        pattern = self.pattern.name,
        crashPoint = (self.status == "crashed") and self.crashPoint or nil
    }
end

function AviatorRound:addPlayer(player, bet)
    -- Verificar si el jugador ya está en la ronda
    for _, p in pairs(self.players) do
        if p.element == player then
            return false, "Ya estás en esta ronda"
        end
    end
    
    -- Validar apuesta
    if not config.isValidBet(bet) then
        return false, "Apuesta inválida"
    end
    
    -- Agregar jugador
    table.insert(self.players, {
        element = player,
        bet = bet,
        cashedOut = false,
        joinTime = getTickCount()
    })
    
    return true
end

function AviatorRound:cashOut(player)
    for _, p in pairs(self.players) do
        if p.element == player and not p.cashedOut then
            if self.status ~= "flying" then
                return false, "No puedes cobrar en este momento"
            end
            
            p.cashedOut = true
            local winAmount = math.floor(p.bet * self.multiplier)
            
            -- Procesar victoria
            exports.casino:processWin(player, winAmount, "aviator")
            
            -- Notificar al jugador
            triggerClientEvent(player, "onAviatorCashOut", resourceRoot, {
                multiplier = self.multiplier,
                winAmount = winAmount
            })
            
            return true, winAmount
        end
    end
    
    return false, "No estás en esta ronda"
end

-- Funciones globales

function startNewRound()
    -- Limpiar ronda anterior
    if activeRound then
        if activeRound.status == "flying" then
            activeRound:crash()
        end
        activeRound = nil
    end
    
    -- Crear nueva ronda
    activeRound = AviatorRound:new()
    activeRound:initialize()
    
    -- Iniciar temporizador de actualización
    if updateTimer then
        killTimer(updateTimer)
    end
    updateTimer = setTimer(function()
        if activeRound then
            activeRound:update()
        end
    end, config.getConfig("aviator", "updateInterval"), 0)
end

-- Funciones de manejo de eventos

function onAviatorJoin(player, bet)
    if not activeRound then
        startNewRound()
    end
    
    local success, result = activeRound:addPlayer(player, bet)
    if success then
        triggerClientEvent(player, "onAviatorJoinSuccess", resourceRoot, activeRound:getState())
    else
        triggerClientEvent(player, "onAviatorJoinFailed", resourceRoot, result)
    end
    
    return success, result
end

function onAviatorCashOut(player)
    if not activeRound then
        return false, "No hay ronda activa"
    end
    
    return activeRound:cashOut(player)
end

-- Event handlers
addEvent("onAviatorJoin", true)
addEventHandler("onAviatorJoin", root, onAviatorJoin)

addEvent("onAviatorCashOut", true)
addEventHandler("onAviatorCashOut", root, onAviatorCashOut)

-- Inicialización del recurso
addEventHandler("onResourceStart", resourceRoot, function()
    -- Iniciar primera ronda
    startNewRound()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    -- Limpiar temporizadores
    if updateTimer then
        killTimer(updateTimer)
    end
    if roundTimer then
        killTimer(roundTimer)
    end
end)

-- Exportar funciones necesarias
exports = {
    joinGame = onAviatorJoin,
    cashOut = onAviatorCashOut,
    getCurrentMultiplier = function()
        return activeRound and activeRound.multiplier or 1.0
    end,
    isRoundActive = function()
        return activeRound and activeRound.status == "flying"
    end
}
