--[[
TotemTender/README.md

Totem Tender — an idle mini‑game inside WoW Classic Anniversary
-----------------------------------------------------------------------------

Goal: Keep the environment healthy and in harmony by unlocking and summoning Shaman totems.
Win: Reach Shaman Level 60 while the current environment is Thriving.
Loss: Environment health drops to 0 (Collapses).

Folders & Files
- TotemTender.toc
- core.lua           (addon bootstrap, saved vars, game loop, slash cmd)
- ui.lua             (frames, banner, buttons, totem list popups, drag/ESC)
- data.lua           (environments, totems, tuning constants)
- logic.lua          (unlock/summon rules, ticking sim, scoring/leveling)

Notes
- Uses SavedVariables: TotemTenderDB
- UI is draggable and closable with ESC; use /totem or /totemtender to toggle.
- Totem icons use existing Spell_ textures; replace with your preferred ones anytime.
- Interface number in the TOC may need updating for your client build.

]]--