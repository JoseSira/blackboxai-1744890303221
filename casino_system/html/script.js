// Casino System Client Script
let playerBalance = 0;
let currentGame = null;
let isGameActive = false;

// Elementos DOM
const elements = {
    checkpoint: document.getElementById('checkpoint'),
    casinoInterface: document.getElementById('casinoInterface'),
    playerBalance: document.getElementById('playerBalance'),
    rechargeButton: document.getElementById('rechargeButton'),
    closeButton: document.getElementById('closeButton'),
    rechargeModal: document.getElementById('rechargeModal'),
    rechargeAmount: document.getElementById('rechargeAmount'),
    confirmRecharge: document.getElementById('confirmRecharge'),
    cancelRecharge: document.getElementById('cancelRecharge'),
    notifications: document.getElementById('notifications'),
    gameContainers: {
        blackjack: document.getElementById('blackjackGame'),
        poker: document.getElementById('pokerGame'),
        mines: document.getElementById('minesGame'),
        aviator: document.getElementById('aviatorGame')
    }
};

// Configuración
const config = {
    minBet: 1000,
    maxBet: 1000000,
    notificationDuration: 3000,
    animations: {
        duration: 300,
        easing: 'ease-in-out'
    }
};

// Inicialización
document.addEventListener('DOMContentLoaded', () => {
    initializeEventListeners();
    initializeGames();
});

// Inicializar Event Listeners
function initializeEventListeners() {
    // Checkpoint
    elements.checkpoint.querySelector('#enterCasino').addEventListener('click', enterCasino);

    // Botones principales
    elements.rechargeButton.addEventListener('click', showRechargeModal);
    elements.closeButton.addEventListener('click', closeCasino);
    elements.confirmRecharge.addEventListener('click', handleRecharge);
    elements.cancelRecharge.addEventListener('click', hideRechargeModal);

    // Botones de juegos
    document.querySelectorAll('.game-button').forEach(button => {
        button.addEventListener('click', () => selectGame(button.dataset.game));
    });

    // Eventos de juegos específicos
    initializeBlackjackEvents();
    initializePokerEvents();
    initializeMinesEvents();
    initializeAviatorEvents();
}

// Funciones principales

function enterCasino() {
    elements.checkpoint.classList.add('opacity-0');
    setTimeout(() => {
        elements.checkpoint.style.display = 'none';
        elements.casinoInterface.classList.remove('hidden');
        // Notificar al servidor
        mta.triggerServerEvent('onPlayerEnterCasino');
    }, config.animations.duration);
}

function closeCasino() {
    if (isGameActive) {
        showNotification('Debes terminar el juego actual antes de salir', 'warning');
        return;
    }
    
    elements.casinoInterface.classList.add('opacity-0');
    setTimeout(() => {
        elements.casinoInterface.classList.add('hidden');
        elements.checkpoint.style.display = 'flex';
        elements.checkpoint.classList.remove('opacity-0');
        // Notificar al servidor
        mta.triggerServerEvent('onPlayerExitCasino');
    }, config.animations.duration);
}

function showRechargeModal() {
    elements.rechargeModal.classList.remove('hidden');
    elements.rechargeAmount.focus();
}

function hideRechargeModal() {
    elements.rechargeModal.classList.add('hidden');
    elements.rechargeAmount.value = '';
}

function handleRecharge() {
    const amount = parseInt(elements.rechargeAmount.value);
    if (isNaN(amount) || amount < config.minBet) {
        showNotification(`La recarga mínima es $${config.minBet}`, 'error');
        return;
    }
    if (amount > config.maxBet) {
        showNotification(`La recarga máxima es $${config.maxBet}`, 'error');
        return;
    }

    // Notificar al servidor
    mta.triggerServerEvent('onPlayerRecharge', amount);
    hideRechargeModal();
}

function selectGame(gameName) {
    if (isGameActive) {
        showNotification('Ya hay un juego en curso', 'warning');
        return;
    }

    // Ocultar todos los juegos
    Object.values(elements.gameContainers).forEach(container => {
        container.classList.remove('active');
    });

    // Mostrar el juego seleccionado
    elements.gameContainers[gameName].classList.add('active');
    currentGame = gameName;
    
    // Inicializar el juego específico
    switch(gameName) {
        case 'blackjack':
            initializeBlackjackGame();
            break;
        case 'poker':
            initializePokerGame();
            break;
        case 'mines':
            initializeMinesGame();
            break;
        case 'aviator':
            initializeAviatorGame();
            break;
    }
}

// Funciones de utilidad

function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification p-4 rounded-lg shadow-lg ${getNotificationClass(type)}`;
    notification.innerHTML = `
        <div class="flex items-center">
            ${getNotificationIcon(type)}
            <span class="ml-2">${message}</span>
        </div>
    `;
    
    elements.notifications.appendChild(notification);
    
    setTimeout(() => {
        notification.classList.add('opacity-0');
        setTimeout(() => notification.remove(), 300);
    }, config.notificationDuration);
}

function getNotificationClass(type) {
    const classes = {
        success: 'bg-green-600',
        error: 'bg-red-600',
        warning: 'bg-yellow-600',
        info: 'bg-blue-600'
    };
    return classes[type] || classes.info;
}

function getNotificationIcon(type) {
    const icons = {
        success: 'fa-check-circle',
        error: 'fa-times-circle',
        warning: 'fa-exclamation-triangle',
        info: 'fa-info-circle'
    };
    return `<i class="fas ${icons[type] || icons.info}"></i>`;
}

function updateBalance(newBalance) {
    playerBalance = newBalance;
    elements.playerBalance.textContent = `$${newBalance.toLocaleString()}`;
    elements.playerBalance.classList.add('balance-update');
    setTimeout(() => elements.playerBalance.classList.remove('balance-update'), 500);
}

// Eventos del servidor
mta.addEvent('updatePlayerBalance', (balance) => {
    updateBalance(balance);
});

mta.addEvent('showNotification', (message, type) => {
    showNotification(message, type);
});

// Inicialización de juegos específicos

function initializeBlackjackGame() {
    isGameActive = true;
    const container = elements.gameContainers.blackjack;
    // Limpiar manos anteriores
    container.querySelector('#dealerCards').innerHTML = '';
    container.querySelector('#playerCards').innerHTML = '';
    // Notificar al servidor
    mta.triggerServerEvent('onBlackjackStart');
}

function initializePokerGame() {
    isGameActive = true;
    // Implementar lógica de inicialización de poker
    mta.triggerServerEvent('onPokerStart');
}

function initializeMinesGame() {
    isGameActive = true;
    const container = elements.gameContainers.mines;
    const grid = container.querySelector('.mines-grid');
    grid.innerHTML = '';
    
    // Crear grid 5x5
    for (let i = 0; i < 25; i++) {
        const cell = document.createElement('div');
        cell.className = 'mine-cell bg-gray-700 hover:bg-gray-600 rounded-lg aspect-square cursor-pointer transition-colors';
        cell.dataset.index = i;
        cell.addEventListener('click', () => handleMineClick(i));
        grid.appendChild(cell);
    }
    
    mta.triggerServerEvent('onMinesStart');
}

function initializeAviatorGame() {
    isGameActive = true;
    const container = elements.gameContainers.aviator;
    const graph = container.querySelector('.aviator-graph');
    graph.innerHTML = '<canvas id="aviatorCanvas"></canvas>';
    
    mta.triggerServerEvent('onAviatorStart');
}

// Event Handlers específicos de juegos

function initializeBlackjackEvents() {
    const hitButton = document.getElementById('hitButton');
    const standButton = document.getElementById('standButton');
    
    hitButton.addEventListener('click', () => {
        if (!isGameActive) return;
        mta.triggerServerEvent('onBlackjackHit');
    });
    
    standButton.addEventListener('click', () => {
        if (!isGameActive) return;
        mta.triggerServerEvent('onBlackjackStand');
    });
}

function initializePokerEvents() {
    // Implementar eventos específicos del poker
}

function initializeMinesEvents() {
    // Los eventos de minas se manejan en la creación de celdas
}

function initializeAviatorEvents() {
    const cashoutButton = document.getElementById('cashoutButton');
    
    cashoutButton.addEventListener('click', () => {
        if (!isGameActive) return;
        mta.triggerServerEvent('onAviatorCashout');
    });
}

// Handlers de juegos

function handleMineClick(index) {
    if (!isGameActive) return;
    mta.triggerServerEvent('onMineClick', index);
}

// Eventos del servidor para juegos específicos

mta.addEvent('updateBlackjackHand', (playerCards, dealerCards) => {
    // Actualizar visualización de cartas
});

mta.addEvent('updatePokerTable', (tableState) => {
    // Actualizar estado de la mesa de poker
});

mta.addEvent('updateMinesGrid', (revealedCells, isExploded) => {
    // Actualizar grid de minas
});

mta.addEvent('updateAviatorMultiplier', (multiplier) => {
    // Actualizar multiplicador del Aviator
});

mta.addEvent('gameOver', (result, winAmount) => {
    isGameActive = false;
    showNotification(
        result === 'win' 
            ? `¡Ganaste $${winAmount.toLocaleString()}!` 
            : 'Mejor suerte la próxima vez',
        result === 'win' ? 'success' : 'info'
    );
});
