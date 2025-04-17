--[[
    Blackjack Game Logic
    Author: BLACKBOXAI
    Description: Implementación del juego Blackjack para el sistema de casino.
]]

-- Importar configuración
local config = exports.casino_config

-- Variables locales
local activeGames = {}

-- Constantes
local CARD_VALUES = {
    ["A"] = 11,  -- As puede valer 1 u 11
    ["2"] = 2,
    ["3"] = 3,
    ["4"] = 4,
    ["5"] = 5,
    ["6"] = 6,
    ["7"] = 7,
    ["8"] = 8,
    ["9"] = 9,
    ["10"] = 10,
    ["J"] = 10,
    ["Q"] = 10,
    ["K"] = 10
}

local SUITS = {"♠", "♥", "♦", "♣"}
local RANKS = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

-- Clase para manejar el mazo
local Deck = {
    cards = {}
}

function Deck:new()
    local deck = {cards = {}}
    setmetatable(deck, {__index = self})
    deck:initialize()
    return deck
end

function Deck:initialize()
    self.cards = {}
    for _, suit in ipairs(SUITS) do
        for _, rank in ipairs(RANKS) do
            table.insert(self.cards, {rank = rank, suit = suit})
        end
    end
    self:shuffle()
end

function Deck:shuffle()
    local n = #self.cards
    for i = n, 2, -1 do
        local j = math.random(i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

function Deck:draw()
    if #self.cards == 0 then
        self:initialize()
    end
    return table.remove(self.cards)
end

-- Clase para manejar una mano
local Hand = {
    cards = {},
    value = 0
}

function Hand:new()
    local hand = {cards = {}, value = 0}
    setmetatable(hand, {__index = self})
    return hand
end

function Hand:addCard(card)
    table.insert(self.cards, card)
    self:calculateValue()
end

function Hand:calculateValue()
    local value = 0
    local aces = 0
    
    for _, card in ipairs(self.cards) do
        if card.rank == "A" then
            aces = aces + 1
        else
            value = value + CARD_VALUES[card.rank]
        end
    end
    
    -- Manejar ases
    for i = 1, aces do
        if value + 11 <= 21 then
            value = value + 11
        else
            value = value + 1
        end
    end
    
    self.value = value
    return value
end

function Hand:clear()
    self.cards = {}
    self.value = 0
end

-- Clase para manejar un juego de Blackjack
local BlackjackGame = {
    player = nil,
    playerHand = nil,
    dealerHand = nil,
    deck = nil,
    bet = 0,
    status = "waiting" -- waiting, playing, dealer, finished
}

function BlackjackGame:new(player, bet)
    local game = {
        player = player,
        playerHand = Hand:new(),
        dealerHand = Hand:new(),
        deck = Deck:new(),
        bet = bet,
        status = "waiting"
    }
    setmetatable(game, {__index = self})
    return game
end

function BlackjackGame:start()
    -- Verificar apuesta
    if not config.isValidBet(self.bet) then
        return false, "Apuesta inválida"
    end
    
    -- Repartir cartas iniciales
    self.playerHand:addCard(self.deck:draw())
    self.dealerHand:addCard(self.deck:draw())
    self.playerHand:addCard(self.deck:draw())
    self.dealerHand:addCard(self.deck:draw())
    
    self.status = "playing"
    
    -- Verificar Blackjack natural
    if self.playerHand.value == 21 then
        return self:handleNaturalBlackjack()
    end
    
    return true, self:getGameState()
end

function BlackjackGame:hit()
    if self.status ~= "playing" then
        return false, "No puedes pedir carta en este momento"
    end
    
    self.playerHand:addCard(self.deck:draw())
    
    if self.playerHand.value > 21 then
        return self:handleBust()
    end
    
    return true, self:getGameState()
end

function BlackjackGame:stand()
    if self.status ~= "playing" then
        return false, "No puedes plantarte en este momento"
    end
    
    self.status = "dealer"
    return self:playDealer()
end

function BlackjackGame:playDealer()
    -- El dealer debe pedir carta hasta tener 17 o más
    while self.dealerHand.value < config.getConfig("blackjack", "dealerStandValue") do
        self.dealerHand:addCard(self.deck:draw())
    end
    
    return self:determineWinner()
end

function BlackjackGame:handleNaturalBlackjack()
    self.status = "finished"
    local winAmount = self.bet * config.getConfig("blackjack", "blackjackPayout")
    exports.casino:processWin(self.player, winAmount, "blackjack")
    return true, {
        status = "finished",
        result = "blackjack",
        winAmount = winAmount,
        gameState = self:getGameState()
    }
end

function BlackjackGame:handleBust()
    self.status = "finished"
    exports.casino:processLoss(self.player)
    return true, {
        status = "finished",
        result = "bust",
        gameState = self:getGameState()
    }
end

function BlackjackGame:determineWinner()
    self.status = "finished"
    local dealerValue = self.dealerHand.value
    local playerValue = self.playerHand.value
    
    -- Dealer bust
    if dealerValue > 21 then
        local winAmount = self.bet * 2
        exports.casino:processWin(self.player, winAmount, "blackjack")
        return true, {
            status = "finished",
            result = "dealer_bust",
            winAmount = winAmount,
            gameState = self:getGameState()
        }
    end
    
    -- Comparar valores
    if playerValue > dealerValue then
        local winAmount = self.bet * 2
        exports.casino:processWin(self.player, winAmount, "blackjack")
        return true, {
            status = "finished",
            result = "win",
            winAmount = winAmount,
            gameState = self:getGameState()
        }
    elseif playerValue < dealerValue then
        exports.casino:processLoss(self.player)
        return true, {
            status = "finished",
            result = "lose",
            gameState = self:getGameState()
        }
    else
        -- Empate
        givePlayerMoney(self.player, self.bet) -- Devolver apuesta
        return true, {
            status = "finished",
            result = "push",
            gameState = self:getGameState()
        }
    end
end

function BlackjackGame:getGameState()
    return {
        playerHand = {
            cards = self.playerHand.cards,
            value = self.playerHand.value
        },
        dealerHand = {
            cards = self.dealerHand.cards,
            value = self.dealerHand.value,
            hideSecondCard = (self.status == "playing")
        },
        status = self.status,
        bet = self.bet
    }
end

-- Funciones de manejo de eventos

function onBlackjackStart(player, bet)
    local playerID = getElementData(player, "ID") or "unknown"
    
    -- Verificar si el jugador ya tiene un juego activo
    if activeGames[playerID] then
        return false, "Ya tienes un juego activo"
    end
    
    -- Crear nuevo juego
    local game = BlackjackGame:new(player, bet)
    activeGames[playerID] = game
    
    -- Iniciar juego
    local success, result = game:start()
    if success then
        triggerClientEvent(player, "updateBlackjackGame", resourceRoot, result)
    end
    return success, result
end

function onBlackjackHit(player)
    local playerID = getElementData(player, "ID") or "unknown"
    local game = activeGames[playerID]
    
    if not game then
        return false, "No tienes un juego activo"
    end
    
    local success, result = game:hit()
    if success then
        triggerClientEvent(player, "updateBlackjackGame", resourceRoot, result)
    end
    return success, result
end

function onBlackjackStand(player)
    local playerID = getElementData(player, "ID") or "unknown"
    local game = activeGames[playerID]
    
    if not game then
        return false, "No tienes un juego activo"
    end
    
    local success, result = game:stand()
    if success then
        triggerClientEvent(player, "updateBlackjackGame", resourceRoot, result)
        -- Limpiar juego si terminó
        if result.status == "finished" then
            activeGames[playerID] = nil
        end
    end
    return success, result
end

-- Event handlers
addEvent("onBlackjackStart", true)
addEventHandler("onBlackjackStart", root, onBlackjackStart)

addEvent("onBlackjackHit", true)
addEventHandler("onBlackjackHit", root, onBlackjackHit)

addEvent("onBlackjackStand", true)
addEventHandler("onBlackjackStand", root, onBlackjackStand)

-- Exportar funciones necesarias
exports = {
    startGame = onBlackjackStart,
    hit = onBlackjackHit,
    stand = onBlackjackStand
}
