--[[
    Casino System Configuration
    Author: BLACKBOXAI
    Description: Archivo de configuración central para el sistema de casino.
    Aquí se pueden ajustar todas las probabilidades, límites y parámetros del casino.
]]

Config = {
    -- Configuración General
    general = {
        maxBet = 1000000,           -- Apuesta máxima permitida
        minBet = 1000,              -- Apuesta mínima permitida
        maxPayout = 5000000,        -- Pago máximo permitido
        checkpointPosition = {       -- Posición del checkpoint del casino
            x = 2019.75,
            y = 1007.96,
            z = 10.82
        },
        checkpointSize = 2.0,       -- Tamaño del checkpoint
        maxDailyBets = 50,          -- Máximo de apuestas diarias por jugador
        cooldownTime = 60           -- Tiempo en segundos entre apuestas
    },

    -- Configuración de Blackjack
    blackjack = {
        enabled = true,             -- Activar/Desactivar juego
        winProbability = 0.45,      -- Probabilidad base de ganar (0.0 - 1.0)
        payoutMultiplier = 2.0,     -- Multiplicador de pago base
        maxHandValue = 21,          -- Valor máximo de mano
        dealerStandValue = 17,      -- Valor en el que el dealer se planta
        blackjackPayout = 2.5,      -- Pago por Blackjack natural
        maxSplits = 3,             -- Máximo de divisiones permitidas
        insuranceMultiplier = 2.0   -- Multiplicador de pago para seguros
    },

    -- Configuración de Poker
    poker = {
        enabled = true,
        winProbability = 0.40,
        minPlayers = 2,
        maxPlayers = 6,
        blindAmount = {
            small = 100,
            big = 200
        },
        timePerAction = 30,         -- Segundos por acción
        maxRaises = 3,              -- Máximo de subidas por ronda
        minRaiseAmount = 200,       -- Mínimo para subir
        maxBuyIn = 50000,          -- Máximo para entrar a la mesa
        minBuyIn = 2000            -- Mínimo para entrar a la mesa
    },

    -- Configuración de Mines
    mines = {
        enabled = true,
        gridSize = {
            width = 5,
            height = 5
        },
        defaultMines = 3,           -- Cantidad default de minas
        maxMines = 24,              -- Máximo de minas permitidas
        multipliers = {             -- Multiplicadores por casilla segura
            base = 1.2,             -- Multiplicador base
            increment = 0.1,        -- Incremento por casilla
            max = 10.0              -- Multiplicador máximo
        },
        customMultipliers = {       -- Multiplicadores especiales por cantidad de minas
            [3] = { max = 5.0 },
            [5] = { max = 7.5 },
            [10] = { max = 15.0 },
            [24] = { max = 100.0 }
        }
    },

    -- Configuración de Aviator
    aviator = {
        enabled = true,
        baseMultiplier = 1.0,
        crashProbability = {
            min = 1.0,              -- Multiplicador mínimo de crash
            max = 100.0             -- Multiplicador máximo de crash
        },
        multiplierSpeed = 0.5,      -- Velocidad de incremento del multiplicador
        maxWinProbability = 0.35,   -- Probabilidad máxima de ganar
        updateInterval = 100,       -- Intervalo de actualización en ms
        patterns = {                -- Patrones de crash predefinidos
            easy = { min = 1.2, max = 2.0, probability = 0.4 },
            medium = { min = 2.0, max = 5.0, probability = 0.3 },
            hard = { min = 5.0, max = 10.0, probability = 0.2 },
            extreme = { min = 10.0, max = 100.0, probability = 0.1 }
        }
    },

    -- Sistema de Recompensas
    rewards = {
        enabled = true,
        firstTimeBonus = 10000,     -- Bonus primera vez
        dailyBonus = 5000,          -- Bonus diario
        vipMultiplier = 1.5,        -- Multiplicador para VIPs
        weeklyBonus = 25000,        -- Bonus semanal
        monthlyBonus = 100000,      -- Bonus mensual
        loyaltyPoints = {           -- Sistema de puntos de lealtad
            enabled = true,
            pointsPerBet = 1,       -- Puntos por apuesta
            minBetForPoints = 1000,  -- Apuesta mínima para recibir puntos
            redemptionRate = 100    -- Dinero por punto al canjear
        }
    },

    -- Sistema Anti-Trampas
    security = {
        maxWinsPerHour = 10,        -- Máximo de victorias por hora
        maxLossesPerHour = 20,      -- Máximo de pérdidas por hora
        suspiciousWinThreshold = 1000000,  -- Umbral para marcar ganancias sospechosas
        maxBetStreak = 15,          -- Máximo de apuestas consecutivas
        cooldownAfterStreak = 300,  -- Tiempo de espera después de racha (segundos)
        patterns = {                -- Patrones sospechosos
            maxWinStreak = 5,       -- Máximo de victorias consecutivas
            maxLossStreak = 10      -- Máximo de pérdidas consecutivas
        }
    },

    -- Mensajes Personalizables
    messages = {
        welcome = "¡Bienvenido al Casino!",
        insufficientFunds = "Fondos insuficientes",
        maxBetReached = "Has alcanzado el límite máximo de apuesta",
        winMessage = "¡Felicitaciones! Has ganado %s$",
        loseMessage = "¡Mejor suerte la próxima vez!",
        cooldownActive = "Debes esperar %s segundos antes de volver a apostar",
        invalidBet = "La apuesta debe estar entre %s$ y %s$",
        dailyLimitReached = "Has alcanzado el límite diario de apuestas",
        suspiciousActivity = "Actividad sospechosa detectada",
        maintenance = "El casino está en mantenimiento",
        vipWelcome = "¡Bienvenido VIP! Disfruta de tu multiplicador x%s"
    }
}

-- Funciones de utilidad para el config

-- Obtener un valor de configuración
function getConfig(category, parameter)
    if Config[category] and Config[category][parameter] then
        return Config[category][parameter]
    end
    return nil
end

-- Actualizar un valor de configuración (solo server-side)
function updateConfig(category, parameter, value)
    if Config[category] and Config[category][parameter] != nil then
        Config[category][parameter] = value
        return true
    end
    return false
end

-- Validar una apuesta
function isValidBet(amount)
    return amount and 
           type(amount) == "number" and 
           amount >= Config.general.minBet and 
           amount <= Config.general.maxBet
end

-- Calcular probabilidad de victoria
function calculateWinProbability(game, betAmount)
    if not Config[game] or not Config[game].winProbability then
        return 0
    end

    local baseProb = Config[game].winProbability
    
    -- Ajustes basados en la cantidad apostada
    if betAmount > Config.general.maxBet * 0.75 then
        baseProb = baseProb * 0.8  -- Reduce probabilidad para apuestas altas
    elseif betAmount < Config.general.minBet * 2 then
        baseProb = baseProb * 1.1  -- Aumenta ligeramente para apuestas bajas
    end

    -- Nunca exceder 100% o ser menor que 0%
    return math.max(0, math.min(1, baseProb))
end

-- Verificar límites de seguridad
function checkSecurityLimits(playerID, isWin)
    local stats = getPlayerStats(playerID)
    if not stats then return false end

    -- Verificar límites por hora
    if isWin and stats.winsThisHour >= Config.security.maxWinsPerHour then
        return false, "Has alcanzado el límite de victorias por hora"
    end

    if not isWin and stats.lossesThisHour >= Config.security.maxLossesPerHour then
        return false, "Has alcanzado el límite de pérdidas por hora"
    end

    -- Verificar rachas
    if stats.currentStreak >= Config.security.maxBetStreak then
        return false, "Necesitas tomar un descanso"
    end

    return true
end

-- Obtener multiplicador de recompensa
function getRewardMultiplier(playerID)
    local multiplier = 1.0
    
    -- Verificar si el jugador es VIP
    if isPlayerVIP(playerID) then
        multiplier = multiplier * Config.rewards.vipMultiplier
    end
    
    return multiplier
end

-- Exportar funciones para uso en otros archivos
exports = {
    getConfig = getConfig,
    updateConfig = updateConfig,
    isValidBet = isValidBet,
    calculateWinProbability = calculateWinProbability,
    checkSecurityLimits = checkSecurityLimits,
    getRewardMultiplier = getRewardMultiplier
}
