--[[
    Mines Game Logic
    Author: BLACKBOXAI
    Description: Implementación del juego de Minas para el sistema de casino.
    Similar a Minesweeper pero con sistema de apuestas y multiplicadores.
]]

-- Importar configuración
local config = exports.casino_config

-- Variables locales
local activeGames = {}

-- Clase para manejar el juego de Minas
local MinesGame = {
    player = nil,
    grid = {},
    minePositions = {},
    revealedCells = {},
    bet = 0,
    numberOfMines = 0,
    currentMultiplier = 1.0,
    status = "waiting", -- waiting, playing, finished
    gridSize = {
        width = 5,
        height = 5
    }
}

function MinesGame:new(player, bet, mines)
    -- Validar número de minas
    local maxMines = config.getConfig("mines", "maxMines")
    local defaultMines = config.getConfig("mines", "defaultMines")
    mines = mines or defaultMines
    
    if mines > maxMines then
        mines = maxMines
    end

    local game = {
        player = player,
        grid = {},
        minePositions = {},
        revealedCells = {},
        bet = bet,
        numberOfMines = mines,
        currentMultiplier = 1.0,
        status = "waiting",
        gridSize = config.getConfig("mines", "gridSize")
    }
    setmetatable(game, {__index = self})
    return game
end

function MinesGame:initialize()
    -- Crear grid vacío
    for i = 1, self.gridSize.width * self.gridSize.height do
        self.grid[i] = false -- false = no es mina
    end
    
    -- Colocar minas aleatoriamente
    local minesPlaced = 0
    while minesPlaced < self.numberOfMines do
        local pos = math.random(1, self.gridSize.width * self.gridSize.height)
        if not self.grid[pos] then
            self.grid[pos] = true -- true = es mina
            table.insert(self.minePositions, pos)
            minesPlaced = minesPlaced + 1
        end
    end
    
    self.status = "playing"
    return true
end

function MinesGame:revealCell(cellIndex)
    if self.status ~= "playing" then
        return false, "El juego no está activo"
    end
    
    if self.revealedCells[cellIndex] then
        return false, "Celda ya revelada"
    end
    
    -- Marcar celda como revelada
    self.revealedCells[cellIndex] = true
    
    -- Verificar si es mina
    if self.grid[cellIndex] then
        return self:handleLoss()
    end
    
    -- Calcular nuevo multiplicador
    self:updateMultiplier()
    
    -- Verificar si ganó (reveló todas las celdas seguras)
    if self:checkWinCondition() then
        return self:handleWin()
    end
    
    return true, self:getGameState()
end

function MinesGame:updateMultiplier()
    local baseMultiplier = config.getConfig("mines", "multipliers").base
    local increment = config.getConfig("mines", "multipliers").increment
    local maxMultiplier = config.getConfig("mines", "multipliers").max
    
    -- Calcular multiplicador basado en celdas reveladas y número de minas
    local revealedCount = self:getRevealedCount()
    local multiplier = baseMultiplier + (increment * revealedCount)
    
    -- Ajustar según cantidad de minas
    local mineMultiplier = self:getMineMultiplier()
    multiplier = multiplier * mineMultiplier
    
    -- No exceder el máximo permitido
    self.currentMultiplier = math.min(multiplier, maxMultiplier)
end

function MinesGame:getMineMultiplier()
    -- Obtener multiplicador especial según cantidad de minas
    local customMultipliers = config.getConfig("mines", "customMultipliers")
    if customMultipliers[self.numberOfMines] then
        return customMultipliers[self.numberOfMines].max / 
               config.getConfig("mines", "multipliers").max
    end
    return 1.0
end

function MinesGame:getRevealedCount()
    local count = 0
    for _ in pairs(self.revealedCells) do
        count = count + 1
    end
    return count
end

function MinesGame:checkWinCondition()
    local totalCells = self.gridSize.width * self.gridSize.height
    local safeCells = totalCells - self.numberOfMines
    return self:getRevealedCount() >= safeCells
end

function MinesGame:handleWin()
    self.status = "finished"
    local winAmount = math.floor(self.bet * self.currentMultiplier)
    
    -- Procesar victoria
    exports.casino:processWin(self.player, winAmount, "mines")
    
    return true, {
        status = "finished",
        result = "win",
        winAmount = winAmount,
        multiplier = self.currentMultiplier,
        gameState = self:getGameState()
    }
end

function MinesGame:handleLoss()
    self.status = "finished"
    
    -- Procesar pérdida
    exports.casino:processLoss(self.player)
    
    return true, {
        status = "finished",
        result = "loss",
        gameState = self:getFullGameState() -- Mostrar todas las minas al perder
    }
end

function MinesGame:cashOut()
    if self.status ~= "playing" then
        return false, "No puedes cobrar en este momento"
    end
    
    if self:getRevealedCount() == 0 then
        return false, "Debes revelar al menos una celda"
    end
    
    return self:handleWin()
end

function MinesGame:getGameState()
    return {
        gridSize = self.gridSize,
        revealedCells = self.revealedCells,
        currentMultiplier = self.currentMultiplier,
        numberOfMines = self.numberOfMines,
        bet = self.bet,
        status = self.status
    }
end

function MinesGame:getFullGameState()
    local state = self:getGameState()
    state.minePositions = self.minePositions
    return state
end

-- Funciones de manejo de eventos

function onMinesStart(player, bet, mines)
    local playerID = getElementData(player, "ID") or "unknown"
    
    -- Verificar si el jugador ya tiene un juego activo
    if activeGames[playerID] then
        return false, "Ya tienes un juego activo"
    end
    
    -- Validar apuesta
    if not config.isValidBet(bet) then
        return false, "Apuesta inválida"
    end
    
    -- Crear nuevo juego
    local game = MinesGame:new(player, bet, mines)
    activeGames[playerID] = game
    
    -- Inicializar juego
    local success = game:initialize()
    if success then
        return true, game:getGameState()
    end
    
    return false, "Error al inicializar el juego"
end

function onMineClick(player, cellIndex)
    local playerID = getElementData(player, "ID") or "unknown"
    local game = activeGames[playerID]
    
    if not game then
        return false, "No tienes un juego activo"
    end
    
    local success, result = game:revealCell(cellIndex)
    
    -- Si el juego terminó, limpiarlo
    if result and result.status == "finished" then
        activeGames[playerID] = nil
    end
    
    return success, result
end

function onMinesCashOut(player)
    local playerID = getElementData(player, "ID") or "unknown"
    local game = activeGames[playerID]
    
    if not game then
        return false, "No tienes un juego activo"
    end
    
    local success, result = game:cashOut()
    
    -- Si el cobro fue exitoso, limpiar el juego
    if success then
        activeGames[playerID] = nil
    end
    
    return success, result
end

-- Event handlers
addEvent("onMinesStart", true)
addEventHandler("onMinesStart", root, onMinesStart)

addEvent("onMineClick", true)
addEventHandler("onMineClick", root, onMineClick)

addEvent("onMinesCashOut", true)
addEventHandler("onMinesCashOut", root, onMinesCashOut)

-- Exportar funciones necesarias
exports = {
    startGame = onMinesStart,
    revealCell = onMineClick,
    cashOut = onMinesCashOut
}
