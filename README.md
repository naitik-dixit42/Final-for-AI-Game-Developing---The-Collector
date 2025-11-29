# The Collector (LOVE2D)

A simple 2D top-down collection game built with LOVE2D (Lua).

Features:
- Player moves with arrow keys or WASD
- Items (gems of different colors) spawn randomly
- Enemies patrol and chase the player if nearby
- Traps damage the player
- Win when required numbers of items are collected
- Game over when lives run out
- Synthesized sounds and looping background music (no external assets required)

Code Note:
- lib is a folder inside the folder (final) storing all files, lib is the folder for files like enemy.lua, player.lua etc. So if you see lib anywhere don't get confused.

Run (desktop):

1. Install LOVE2D: https://love2d.org
2. From this folder run:

```powershell
love .
```

Run in browser:
- Use love.js / emscripten builds to export to WASM; see https://love2d.org/wiki/love.js



