--[[
    Poker Game Logic
    Author: BLACKBOXAI
    Description: Implementación del juego de Poker (Texas Hold'em) para el sistema de casino.
]]

-- Importar configuración
local config = exports.casino_config

-- Variables locales
local activeGames = {}
local activeTables = {}

-- Constantes
local CARD_VALUES = {
    ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7,
    ["8"] = 8, ["9"] = 9, ["10"] = 10, ["J"] = 11, ["Q"] = 12, ["K"] = 13, ["A"] = 14
}

local SUITS = {"♠", "♥", "♦", "♣"}
local RANKS = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}

-- Enums
local HAND_RANKINGS = {
    HIGH_CARD = 1,
    PAIR = 2,
    TWO_PAIR = 3,
    THREE_OF_A_KIND = 4,
    STRAIGHT = 5,
    FLUSH = 6,
    FULL_HOUSE = 7,
    FOUR_OF_A_KIND = 8,
    STRAIGHT_FLUSH = 9,
    ROYAL_FLUSH = 10
}

local GAME_PHASES = {
    WAITING = "waiting",
    PREFLOP = "preflop",
    FLOP = "flop",
    TURN = "turn",
    RIVER = "river",
    SHOWDOWN = "showdown"
}

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
            table.insert(self.cards, {rank = rank, suit = suit, value = CARD_VALUES[rank]})
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

-- Clase para manejar una mesa de poker
local PokerTable = {
    id = nil,
    players = {},
    deck = nil,
    communityCards = {},
    pot = 0,
    currentBet = 0,
    phase = GAME_PHASES.WAITING,
    activePlayerIndex = 1,
    dealer = 1,
    smallBlind = nil,
    bigBlind = nil,
    lastRaiseAmount = 0,
    minPlayers = 2,
    maxPlayers = 6
}

function PokerTable:new(id)
    local table = {
        id = id,
        players = {},
        deck = Deck:new(),
        communityCards = {},
        pot = 0,
        currentBet = 0,
        phase = GAME_PHASES.WAITING,
        activePlayerIndex = 1,
        dealer = 1,
        smallBlind = config.getConfig("poker", "blindAmount").small,
        bigBlind = config.getConfig("poker", "blindAmount").big,
        lastRaiseAmount = 0,
        minPlayers = config.getConfig("poker", "minPlayers"),
        maxPlayers = config.getConfig("poker", "maxPlayers")
    }
    setmetatable(table, {__index = self})
    return table
end

function PokerTable:addPlayer(player, buyIn)
    if #self.players >= self.maxPlayers then
        return false, "Mesa llena"
    end
    
    if buyIn < config.getConfig("poker", "minBuyIn") or 
       buyIn > config.getConfig("poker", "maxBuyIn") then
        return false, "Buy-in inválido"
    end
    
    local playerData = {
        element = player,
        chips = buyIn,
        hand = {},
        bet = 0,
        folded = false,
        allIn = false
    }
    
    table.insert(self.players, playerData)
    
    -- Si tenemos suficientes jugadores, podemos comenzar
    if #self.players >= self.minPlayers and self.phase == GAME_PHASES.WAITING then
        self:startNewHand()
    end
    
    return true
end

function PokerTable:removePlayer(player)
    for i, p in ipairs(self.players) do
        if p.element == player then
            -- Devolver chips restantes al jugador
            if p.chips > 0 then
                givePlayerMoney(player, p.chips)
            end
            table.remove(self.players, i)
            
            -- Si no hay suficientes jugadores, terminar el juego
            if #self.players < self.minPlayers then
                self:endGame()
            end
            return true
        end
    end
    return false
end

function PokerTable:startNewHand()
    -- Reiniciar el estado de la mesa
    self.deck:initialize()
    self.communityCards = {}
    self.pot = 0
    self.currentBet = 0
    self.phase = GAME_PHASES.PREFLOP
    self.lastRaiseAmount = self.bigBlind
    
    -- Rotar el dealer
    self.dealer = (self.dealer % #self.players) + 1
    
    -- Reiniciar estado de los jugadores
    for _, player in ipairs(self.players) do
        player.hand = {}
        player.bet = 0
        player.folded = false
        player.allIn = false
    end
    
    -- Repartir cartas iniciales
    self:dealPlayerCards()
    
    -- Cobrar blinds
    self:collectBlinds()
    
    -- Comenzar primera ronda de apuestas
    self:startBettingRound()
end

function PokerTable:dealPlayerCards()
    -- Dar dos cartas a cada jugador
    for i = 1, 2 do
        for _, player in ipairs(self.players) do
            table.insert(player.hand, self.deck:draw())
        end
    end
end

function PokerTable:collectBlinds()
    local smallBlindPos = (self.dealer % #self.players) + 1
    local bigBlindPos = ((self.dealer + 1) % #self.players) + 1
    
    -- Cobrar small blind
    self:placeBet(self.players[smallBlindPos], self.smallBlind)
    
    -- Cobrar big blind
    self:placeBet(self.players[bigBlindPos], self.bigBlind)
    
    self.currentBet = self.bigBlind
end

function PokerTable:placeBet(player, amount)
    -- Verificar si el jugador tiene suficientes chips
    local actualBet = math.min(amount, player.chips)
    player.chips = player.chips - actualBet
    player.bet = player.bet + actualBet
    self.pot = self.pot + actualBet
    
    if player.chips == 0 then
        player.allIn = true
    end
    
    return actualBet
end

function PokerTable:evaluateHand(cards)
    -- Ordenar cartas por valor
    table.sort(cards, function(a, b) return a.value > b.value end)
    
    -- Verificar royal flush
    if self:isRoyalFlush(cards) then
        return HAND_RANKINGS.ROYAL_FLUSH
    end
    
    -- Verificar straight flush
    if self:isStraightFlush(cards) then
        return HAND_RANKINGS.STRAIGHT_FLUSH
    end
    
    -- Verificar four of a kind
    if self:isFourOfAKind(cards) then
        return HAND_RANKINGS.FOUR_OF_A_KIND
    end
    
    -- Verificar full house
    if self:isFullHouse(cards) then
        return HAND_RANKINGS.FULL_HOUSE
    end
    
    -- Verificar flush
    if self:isFlush(cards) then
        return HAND_RANKINGS.FLUSH
    end
    
    -- Verificar straight
    if self:isStraight(cards) then
        return HAND_RANKINGS.STRAIGHT
    end
    
    -- Verificar three of a kind
    if self:isThreeOfAKind(cards) then
        return HAND_RANKINGS.THREE_OF_A_KIND
    end
    
    -- Verificar two pair
    if self:isTwoPair(cards) then
        return HAND_RANKINGS.TWO_PAIR
    end
    
    -- Verificar pair
    if self:isPair(cards) then
        return HAND_RANKINGS.PAIR
    end
    
    return HAND_RANKINGS.HIGH_CARD
end

-- Funciones auxiliares para evaluar manos
function PokerTable:isRoyalFlush(cards)
    if not self:isStraightFlush(cards) then return false end
    return cards[1].value == CARD_VALUES["A"]
end

function PokerTable:isStraightFlush(cards)
    return self:isFlush(cards) and self:isStraight(cards)
end

function PokerTable:isFourOfAKind(cards)
    local counts = self:getValueCounts(cards)
    for _, count in pairs(counts) do
        if count == 4 then return true end
    end
    return false
end

function PokerTable:isFullHouse(cards)
    local counts = self:getValueCounts(cards)
    local hasThree, hasTwo = false, false
    for _, count in pairs(counts) do
        if count == 3 then hasThree = true
        elseif count == 2 then hasTwo = true end
    end
    return hasThree and hasTwo
end

function PokerTable:isFlush(cards)
    local suit = cards[1].suit
    for i = 2, #cards do
        if cards[i].suit ~= suit then return false end
    end
    return true
end

function PokerTable:isStraight(cards)
    for i = 1, #cards - 1 do
        if cards[i].value ~= cards[i + 1].value + 1 then
            -- Verificar caso especial: As puede ser 1 en un straight
            if not (i == 1 and cards[1].value == 14 and cards[2].value == 5) then
                return false
            end
        end
    end
    return true
end

function PokerTable:isThreeOfAKind(cards)
    local counts = self:getValueCounts(cards)
    for _, count in pairs(counts) do
        if count == 3 then return true end
    end
    return false
end

function PokerTable:isTwoPair(cards)
    local pairs = 0
    local counts = self:getValueCounts(cards)
    for _, count in pairs(counts) do
        if count == 2 then pairs = pairs + 1 end
    end
    return pairs == 2
end

function PokerTable:isPair(cards)
    local counts = self:getValueCounts(cards)
    for _, count in pairs(counts) do
        if count == 2 then return true end
    end
    return false
end

function PokerTable:getValueCounts(cards)
    local counts = {}
    for _, card in ipairs(cards) do
        counts[card.value] = (counts[card.value] or 0) + 1
    end
    return counts
end

-- Eventos del servidor
addEvent("onPokerPlayerJoin", true)
addEventHandler("onPokerPlayerJoin", root, function(player, buyIn)
    -- Buscar mesa disponible o crear una nueva
    local table = nil
    for _, t in pairs(activeTables) do
        if #t.players < t.maxPlayers then
            table = t
            break
        end
    end
    
    if not table then
        local tableId = #activeTables + 1
        table = PokerTable:new(tableId)
        activeTables[tableId] = table
    end
    
    local success, message = table:addPlayer(player, buyIn)
    if success then
        triggerClientEvent(player, "onPokerJoinSuccess", resourceRoot, table.id)
    else
        triggerClientEvent(player, "onPokerJoinFailed", resourceRoot, message)
    end
end)

addEvent("onPokerPlayerLeave", true)
addEventHandler("onPokerPlayerLeave", root, function(player)
    for _, table in pairs(activeTables) do
        if table:removePlayer(player) then
            triggerClientEvent(player, "onPokerLeaveSuccess", resourceRoot)
            break
        end
    end
end)

-- Exportar funciones necesarias
exports = {
    createTable = function() 
        local tableId = #activeTables + 1
        local table = PokerTable:new(tableId)
        activeTables[tableId] = table
        return tableId
    end,
    joinTable = function(player, tableId, buyIn)
        local table = activeTables[tableId]
        if table then
            return table:addPlayer(player, buyIn)
        end
        return false, "Mesa no encontrada"
    end,
    leaveTable = function(player, tableId)
        local table = activeTables[tableId]
        if table then
            return table:removePlayer(player)
        end
        return false, "Mesa no encontrada"
    end
}
