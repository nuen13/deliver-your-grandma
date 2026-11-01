# Grandma's Wild Delivery

A funny single-player Roblox roguelike. The player pushes Grandma in a wheelchair through random rooms. Servers hold one player.

## Workflow
- Scripts live in `src/` and sync to Studio through Rojo. Don't edit synced scripts in Studio or through the Studio MCP: Rojo can overwrite those edits.
- Use the Studio MCP to inspect the running game, and to build rooms and models. Those live in the place file, not Git.
- Do one small task at a time. The user playtests feel and comedy; commit only when they ask.

## Structure
- `src/shared/Config.luau`: every tuning value. Don't hard-code gameplay numbers elsewhere.
- `src/shared/Data/`: content as data (rooms and voice lines now; upgrades and hazards later).
- `src/server/`: world building, Grandma, and anything that decides rewards, damage, or saves.
- `src/client/`: wheelchair input and physics (the player has network ownership), and reactions.

## Rules
- Never trust the client. Validate every remote on the server, and keep rewards and saves server-side.
- All run randomness must come from a seeded `Random.new(seed)` so runs can be reproduced.
- New content should mean adding data, not new systems.
- Use `--!strict` in every script.

## Build order
1. Feel: pushing and Grandma falling out in one test room (done)
2. Failure: Patience, crashes, and restarting a run (done)
3. Run structure: three seeded rooms with exits (done)
4. Choices: upgrade cards and about five upgrades (built, awaiting playtest)
5. Comedy: more Grandma lines and reactions (built, awaiting playtest)
6. Progress: Bingo Tickets, saved unlocks, and a boss (built, awaiting playtest)
7. Content: about 10 rooms, 5 hazards, and 20 upgrades (built, awaiting playtest)
8. Release: playtest, then follow `PUBLISHING.md` (current)
