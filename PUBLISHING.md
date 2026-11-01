# Publishing checklist

These steps need your Roblox account. Menu names may differ a little between Studio versions.

## 1. Playtest in Studio
Press Play with Rojo connected, and check that the Output window shows no red errors.

Studio chat commands for testing:
- `!god` turns off Patience loss.
- `!tickets 500` adds Bingo Tickets for testing the shop.
- `!room 6` jumps to the boss room, once a run has started.
- `!seed 1234` replays a run.

Go through this list:
- [ ] The menu opens, and Play starts a run.
- [ ] Upgrade cards appear after each room, and picking one continues the run.
- [ ] Each hazard works: cat, spinning sweeper, falling piano, oil, and mud.
- [ ] Collecting B-I-N-G-O removes Mildred and opens the gate.
- [ ] Reaching the Bingo Hall wins the run and awards tickets.
- [ ] The shop unlocks cards, and they later appear in runs.
- [ ] Every sound plays. Replace any that don't in `Sfx` in `src/shared/Config.luau`.
- [ ] Touch controls work (Studio's device emulator, then a real phone).
- [ ] A gamepad works, if you plan to advertise support.

## 2. Add your voice (optional)
Upload your clip, then set `VoiceSoundId = "rbxassetid://YOUR_ID"` in `src/shared/Config.luau`.

## 3. Publish
1. Save the place to Roblox: **File > Publish to Roblox**.
2. Keep it private at first.

## 4. Test saving
1. In **Game Settings > Security**, turn on **Enable Studio Access to API Services**.
2. Earn tickets, stop the game, and play again. The tickets should still be there.
3. The red "progress can't be saved" message should be gone from the menu.

## 5. Go public
1. Add a name, description, icon, and thumbnails on the Creator Hub.
2. Complete the maturity and compliance questionnaire.
3. Set the max players per server to 1 in the game's Places settings.
4. Play the live version once on a computer and once on a phone.
5. Change the game to Public.
