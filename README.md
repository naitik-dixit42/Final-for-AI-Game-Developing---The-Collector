# The Collector (LOVE2D)

A simple 2D top-down collection game built with LOVE2D (Lua).

Features:
- Player moves with arrow keys or WASD
- Items (coins, stars, carrots) spawn randomly
- Enemies patrol and chase the player if nearby
- Traps damage the player
- Win when required numbers of items are collected
- Game over when lives run out
- Synthesized sounds and looping background music (no external assets required)

Run (desktop):

1. Install LOVE2D: https://love2d.org
2. From this folder run:

```powershell
love .
```

Run in browser:
- Use love.js / emscripten builds to export to WASM; see https://love2d.org/wiki/love.js

Notes:
- The project uses generated sounds at runtime so there are no audio files to ship.
- The code is modular under `lib/`.
