# Sistema de Casino para MTA:SA

Sistema completo de casino para MTA:SA con múltiples juegos y una interfaz moderna.

## Características

- Interfaz moderna y responsive usando Tailwind CSS
- Sistema de checkpoint para activar el casino
- Sistema de recarga integrado con la economía del servidor
- Múltiples juegos:
  - Blackjack
  - Poker
  - Mines
  - Aviator
- Sistema de probabilidades configurable
- Validaciones y medidas anti-trampas
- Diseño modular y fácilmente extensible

## Instalación

1. Copiar la carpeta `casino_system` al directorio `resources` de tu servidor
2. Agregar el recurso al `mtaserver.conf`:
   ```xml
   <resource src="casino_system" startup="1" protected="0" />
   ```
3. Reiniciar el servidor o cargar el recurso mediante la consola:
   ```
   refresh
   start casino_system
   ```

## Configuración

### Configuración General

Todos los parámetros del casino se pueden configurar en el archivo `lua/config.lua`:

- Límites de apuestas
- Probabilidades de victoria
- Multiplicadores
- Posición del checkpoint
- Mensajes personalizados

### Configuración por Juego

#### Blackjack
```lua
blackjack = {
    enabled = true,             -- Activar/Desactivar juego
    winProbability = 0.45,      -- Probabilidad base de ganar
    payoutMultiplier = 2.0,     -- Multiplicador de pago
    maxHandValue = 21,          -- Valor máximo de mano
    dealerStandValue = 17       -- Valor en el que el dealer se planta
}
```

#### Poker
```lua
poker = {
    enabled = true,
    winProbability = 0.40,
    minPlayers = 2,
    maxPlayers = 6,
    blindAmount = {
        small = 100,
        big = 200
    }
}
```

#### Mines
```lua
mines = {
    enabled = true,
    gridSize = {width = 5, height = 5},
    defaultMines = 3,
    maxMines = 24,
    multipliers = {
        base = 1.2,
        increment = 0.1,
        max = 10.0
    }
}
```

#### Aviator
```lua
aviator = {
    enabled = true,
    baseMultiplier = 1.0,
    crashProbability = {
        min = 1.0,
        max = 100.0
    },
    multiplierSpeed = 0.5
}
```

## Uso

### Para Jugadores

1. Acercarse al checkpoint del casino (marcado en el mapa)
2. Hacer clic en el checkpoint para abrir la interfaz
3. Seleccionar un juego
4. Realizar apuesta y jugar

### Para Administradores

#### Modificar Probabilidades
```lua
exports.casino_system:updateConfig("blackjack", "winProbability", 0.40)
exports.casino_system:updateConfig("poker", "winProbability", 0.35)
```

#### Modificar Límites
```lua
exports.casino_system:updateConfig("general", "maxBet", 1000000)
exports.casino_system:updateConfig("general", "minBet", 1000)
```

## Seguridad

El sistema incluye varias medidas de seguridad:

- Validación de apuestas
- Límites de victorias por hora
- Detección de patrones sospechosos
- Protección contra exploits
- Sistema anti-trampas configurable

## Estructura de Archivos

```
casino_system/
├── html/
│   ├── index.html    # Interfaz principal
│   └── script.js     # Lógica del cliente
├── lua/
│   ├── config.lua    # Configuración central
│   ├── casino.lua    # Lógica principal
│   └── games/        # Lógica de juegos
│       ├── blackjack.lua
│       ├── poker.lua
│       ├── mines.lua
│       └── aviator.lua
└── meta.xml         # Configuración del recurso
```

## Funciones Exportadas

### Server-side
```lua
exports.casino_system:getConfig(category, parameter)
exports.casino_system:updateConfig(category, parameter, value)
exports.casino_system:isValidBet(amount)
exports.casino_system:calculateWinProbability(game, amount)
```

### Juegos
```lua
-- Blackjack
exports.casino_system:startBlackjackGame(player, bet)
exports.casino_system:hitBlackjack(player)
exports.casino_system:standBlackjack(player)

-- Poker
exports.casino_system:createPokerTable()
exports.casino_system:joinPokerTable(player, tableId, buyIn)
exports.casino_system:leavePokerTable(player, tableId)

-- Mines
exports.casino_system:startMinesGame(player, bet, mines)
exports.casino_system:revealMineCell(player, cellIndex)
exports.casino_system:cashOutMines(player)

-- Aviator
exports.casino_system:joinAviatorGame(player, bet)
exports.casino_system:cashOutAviator(player)
exports.casino_system:getCurrentMultiplier()
```

## Personalización

### Interfaz
- Modificar `html/index.html` para cambiar el diseño
- Ajustar estilos en Tailwind CSS
- Personalizar animaciones en `html/script.js`

### Lógica de Juegos
- Modificar archivos en `lua/games/` para ajustar reglas
- Añadir nuevos juegos creando nuevos archivos .lua
- Ajustar probabilidades en `config.lua`

## Soporte

Para reportar bugs o sugerir mejoras, por favor crear un issue en el repositorio.

## Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo LICENSE para más detalles.
