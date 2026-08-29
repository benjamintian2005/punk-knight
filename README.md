# Punk Knight

A Godot 4 game combining a rhythm-game half with a battle-game half.

- **Level Select** — pick a level (Warmup / Rush Hour / Overdrive), each with its own song speed/pattern and enemy pressure.
- **Left side** — hit falling notes on lanes **D F J K** in time with the beat.
- **Right side** — a character fends off enemies (circle/triangle/square/diamond, each with different hp/speed) that spawn and close in. Every note you hit fires a pulse: a **Perfect** hit damages nearby enemies, a **Good** hit knocks them back (no damage). Survive as long as you can — game over triggers a restart prompt (Enter). Escape returns to Level Select at any time.

Levels and enemy types are data-driven: `resources/levels/*.tres` and `resources/enemies/*.tres` (loaded by `GameState.gd`) — add a new level or enemy by dropping in a new `.tres` file, no code changes needed.

## Running

Open the project in Godot 4 and press Play (`scenes/LevelSelect.tscn` is the main scene).
