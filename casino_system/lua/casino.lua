--[[
    Casino System Main File
    Author: BLACKBOXAI
    Description: Archivo principal del sistema de casino.
    Maneja la lógica central, checkpoints y comunicación con el cliente.
]]

-- Importar configuración
local config = exports.casino_config

-- Variables locales
local activeGames = {}
local playerStats = {}
local checkpointMarker = nil

-- Inicialización del sistema
function initializeCasino()
    -- Crear checkpoint
    local pos = config.getConfig("general", "checkpointPosition")
    checkpointMarker = createMarker(
        pos.x, pos.y, pos.z,
        "cylinder",
        config.getConfig("general", "checkpointSize"),
        255, 255, 0, 100  -- Color amarillo semi-transparente
    )
    
    -- Agregar handler para el checkpoint
    addEventHandler("onMarkerHit", checkpointMarker, onPlayerEnterCasino)
    
    -- Inicializar sistemas de juego
    initializeBlackjack()
    initializePoker()
    initializeMines()
    initializeAviator()
    
    outputDebugString("Sistema de casino inicializado correctamente")
end

-- Evento: Jugador entra al casino
function onPlayerEnterCasino(hitElement, matchingDimension)
    if not isElement(hitElement) or getElementType(hitElement) ~= "player" then return end
    if not matchingDimension then return end
    
    local playerID = getElementData(hitElement, "ID") or "unknown"
    
    -- Verificar si el jugador puede entrar
    local canEnter, message = checkPlayerAccess(hitElement)
    if not canEnter then
        outputChatBox(message, hitElement, 255, 0, 0)
        return
    end
    
    -- Inicializar estadísticas del jugador si no existen
    if not playerStats[playerID] then
        playerStats[playerID] = {
            winsThisHour = 0,
            lossesThisHour = 0,
            currentStreak = 0,
            lastBetTime = 0,
            totalBets = 0,
            totalWins = 0,
            totalLosses = 0,
            loyaltyPoints = 0
        }
    end
    
    -- Mostrar interfaz del casino al jugador
    triggerClientEvent(hitElement, "onCasinoEnter", resourceRoot)
    
    -- Mensaje de bienvenida personalizado
    local welcomeMsg = config.getConfig("messages", "welcome")
    if isPlayerVIP(hitElement) then
        local vipMultiplier = config.getConfig("rewards", "vipMultiplier")
        welcomeMsg = string.format(config.getConfig("messages", "vipWelcome"), vipMultiplier)
    end
    outputChatBox(welcomeMsg, hitElement, 0, 255, 0)
end

-- Verificar acceso del jugador
function checkPlayerAccess(player)
    local playerID = getElementData(player, "ID") or "unknown"
    local stats = playerStats[playerID]
    
    -- Verificar cooldown
    if stats and stats.lastBetTime > 0 then
        local timeSinceLastBet = getTickCount() - stats.lastBetTime
        local cooldownTime = config.getConfig("general", "cooldownTime") * 1000
        
        if timeSinceLastBet < cooldownTime then
            return false, string.format(
                config.getConfig("messages", "cooldownActive"),
                math.ceil((cooldownTime - timeSinceLastBet) / 1000)
            )
        end
    end
    
    -- Verificar límite diario
    if stats and stats.totalBets >= config.getConfig("general", "maxDailyBets") then
        return false, config.getConfig("messages", "dailyLimitReached")
    end
    
    return true
end

-- Procesar apuesta
function processBet(player, gameType, amount, ...)
    local playerID = getElementData(player, "ID") or "unknown"
    
    -- Validar apuesta
    if not config.isValidBet(amount) then
        local minBet = config.getConfig("general", "minBet")
        local maxBet = config.getConfig("general", "maxBet")
        outputChatBox(
            string.format(config.getConfig("messages", "invalidBet"), minBet, maxBet),
            player, 255, 0, 0
        )
        return false
    end
    
    -- Verificar fondos
    local playerMoney = getPlayerMoney(player)
    if playerMoney < amount then
        outputChatBox(config.getConfig("messages", "insufficientFunds"), player, 255, 0, 0)
        return false
    end
    
    -- Verificar límites de seguridad
    local canBet, message = config.checkSecurityLimits(playerID, false)
    if not canBet then
        outputChatBox(message, player, 255, 0, 0)
        return false
    end
    
    -- Calcular probabilidad de victoria
    local winProb = config.calculateWinProbability(gameType, amount)
    
    -- Descontar apuesta
    takePlayerMoney(player, amount)
    
    -- Actualizar estadísticas
    updatePlayerStats(playerID, "bet")
    
    -- Devolver resultado para procesar en el juego específico
    return true, winProb
end

-- Actualizar estadísticas del jugador
function updatePlayerStats(playerID, action, isWin)
    if not playerStats[playerID] then return end
    
    local stats = playerStats[playerID]
    stats.lastBetTime = getTickCount()
    
    if action == "bet" then
        stats.totalBets = stats.totalBets + 1
        stats.currentStreak = stats.currentStreak + 1
        
        -- Actualizar puntos de lealtad
        if config.getConfig("rewards", "loyaltyPoints").enabled then
            local minBetForPoints = config.getConfig("rewards", "loyaltyPoints").minBetForPoints
            if amount >= minBetForPoints then
                stats.loyaltyPoints = stats.loyaltyPoints + config.getConfig("rewards", "loyaltyPoints").pointsPerBet
            end
        end
    elseif action == "win" then
        stats.totalWins = stats.totalWins + 1
        stats.winsThisHour = stats.winsThisHour + 1
    elseif action == "loss" then
        stats.totalLosses = stats.totalLosses + 1
        stats.lossesThisHour = stats.lossesThisHour + 1
        stats.currentStreak = 0
    end
end

-- Procesar victoria
function processWin(player, amount, gameType)
    local playerID = getElementData(player, "ID") or "unknown"
    local multiplier = config.getRewardMultiplier(playerID)
    local winAmount = amount * multiplier
    
    -- Verificar límite de pago máximo
    local maxPayout = config.getConfig("general", "maxPayout")
    if winAmount > maxPayout then
        winAmount = maxPayout
    end
    
    -- Dar dinero al jugador
    givePlayerMoney(player, winAmount)
    
    -- Actualizar estadísticas
    updatePlayerStats(playerID, "win")
    
    -- Notificar al jugador
    outputChatBox(
        string.format(config.getConfig("messages", "winMessage"), winAmount),
        player, 0, 255, 0
    )
    
    return winAmount
end

-- Procesar pérdida
function processLoss(player)
    local playerID = getElementData(player, "ID") or "unknown"
    
    -- Actualizar estadísticas
    updatePlayerStats(playerID, "loss")
    
    -- Notificar al jugador
    outputChatBox(config.getConfig("messages", "loseMessage"), player, 255, 0, 0)
end

-- Eventos
addEventHandler("onResourceStart", resourceRoot, initializeCasino)

-- Exportar funciones necesarias
exports = {
    processBet = processBet,
    processWin = processWin,
    processLoss = processLoss,
    updatePlayerStats = updatePlayerStats
}
