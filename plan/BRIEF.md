# Brief for the next session (written 2026-11-13, end of the first long session)

Read this first, then `plan/FEATURES.md` and `plan/DESIGN.md`. Project-wide rules are in `/home/user/Dev/Gaming/Blizzard/AGENTS.md`; Forever facts in `knowledge/forever-vs-vanilla.md`.

## Where things stand
- ProfitCraft is public at github.com/PsiGaming/ProfitCraft (MIT). Released as GitHub pre-releases: 0.1-alpha.0, alpha.1, alpha.2, alpha.3, alpha.4 (alpha.4 = own disenchant estimate). Sylice and friends install via WowUp. Zip name `ProfitCraft-v<version>-forever.zip`, built with `git archive --prefix=ProfitCraft/` (the `plan/` folder is excluded via `.gitattributes`).
- Everything Sylice reported after testing alpha.0-alpha.2 is fixed; disenchant values are rebuilt for alpha.4 (below).
- Version scheme: Sylice decides when a version number changes. **Every commit of addon code is also published** (new `.toc` version, tag, zip, GitHub release): Sylice can only test through WowUp, which only sees releases (Sylice, 2026-11-17). Commits touching only `plan/` need no release.

## Current state: 0.1-alpha.5, published 2026-11-14 as a GitHub pre-release; all of it confirmed working in game by Sylice (2026-11-14)
- alpha.4 (own disenchant estimate, `Disenchant.lua`, DESIGN.md section 12) is published and confirmed working in game by Sylice.
- alpha.5 adds: the disenchant tooltip lists what the item can disenchant into (always shown; Sylice: keep it so); trainer and recipe item tooltips with reagent cost, AH price, profit per craft and craft-and-disenchant (`UI/RecipeTooltip.lua`); bind-on-pickup products get no sale profit anywhere (tooltips, side panel "BoP", recipe details), craft-and-disenchant still shown.
- Forever facts behind the tooltips: PsiLab 0.1-alpha.2 results, `data/psilab/PsiLab-2026-11-14-alpha2-trainer.lua`, written up in `knowledge/forever-vs-vanilla.md`. Unchecked: recipes of professions the character doesn't have.
- Test harness: 84 checks pass.
- **0.1-beta.0 published 2026-11-14** (GitHub pre-release; Sylice: the addon works well enough to leave alpha). So far: price warning banner in the side panel (Auctionator missing / no prices / prices too old) and a settings slider for the age (Off, 1-4 days, default 2); 99 checks pass. Not yet seen in game: the banner and the slider.
- **0.1-beta.1 published 2026-11-14** (briefly published as "0.1-beta.0a", then replaced by beta.1 at Sylice's request; a letter would be fine in the `.toc` version, which is plain text). Before it, the same code was published once more as a recreated beta.0 to test WowUp: no update offered, as predicted (see AGENTS.md). Contents:
- Betas: fixes only; new features go to 0.2. **Next release (Sylice, 2026-11-14):** either `0.1-beta.2` (if fixes are needed) or, once beta.1 is tested enough, the final **`0.1`** (tag `v0.1`, zip `ProfitCraft-v0.1-forever.zip`). **Every release stays a GitHub pre-release, finals included** (Sylice, 2026-11-17; why: AGENTS.md, "Every release is a GitHub pre-release"). From 0.2 on: no alphas; beta = features still being added, rc = fixes only.

- **0.1-rc.0 published 2026-11-17** (GitHub pre-release) (Sylice: "rc" = release candidate, after the betas). One fix: the free bag slots dropdown (FEATURES.md "Version 0.1-rc.0", DESIGN.md "Free bag slots"); 109 checks pass (103 + 4 without Auctionator + the settings upgrade, `/tmp/pcraft-test/upgrade.py`). Next: Sylice tests it in game, then the final `0.1` (or `rc.1` if fixes are needed). After that: 0.2, which starts with a currency window (Sylice, 2026-11-17; design not yet written down).
- **0.2-beta.0 published 2026-11-17**: the money window (FEATURES.md "Version 0.2", DESIGN.md "Money window"); 128 checks pass (+4 without Auctionator, + upgrade check). 0.1 stayed at rc.0 (no separate final: every release is a pre-release anyway, Sylice). Next in 0.2: the own AH scan (DESIGN.md section 9).
- **Settings database version 2** since rc.0 (`Data.lua` upgrades[2]: `reagentBagFreeSlots` -> `freeSlots`).

## How we work
- Evidence for Forever API facts: Blizzard's Forever UI source (Gethe/wow-ui-source, branch `forever`; shallow clone ~54 MB into /tmp) and PsiLab results; reference addons are idea sources, not proof.
- Tests: LuaJIT via `lupa` in a temp venv (`uv venv /tmp/luachk && uv pip install --python /tmp/luachk/bin/python lupa`) with stubbed WoW functions. The test harness lived in `/tmp/pcraft-test/` (`harness.lua`, `run.py`) and will be gone after a reboot; recreate it rather than skipping tests (it simulated login, opening a profession, prices from a fake Auctionator, all windows and settings; 64 checks at alpha.3).
- Sylice reviews uncommitted changes in Claude Code's `/diff` (open Claude Code in the addon's folder). New files: `git add -N`.
- Files Sylice sends arrive in `~/QubesIncoming/<qube>/`: **move** them out immediately (leftovers block the next transfer). PsiLab results go to `data/psilab/`, screenshots to `data/screenshots/`.
- Sylice can't read Lua; explain changes in plain words, keep answers short and concrete.

## Other open items (not urgent)
- `GetAuctionAgeByItemID` unit (whole days?): run PsiLab `/lab run` a day after a scan.
- Shorten the reagent-bag checkbox hover text (it still tells people to use Blizzard's Interface option, now duplicated by the checkbox above it): suggested, not yet approved.
- Sylice mentioned "the shopping list works well" though ProfitCraft has none yet; never clarified (probably meant D/E Bags or Auctionator's list).
- Milestone 0.2 (own AH scan, standalone) and 0.3 (filters, hover breakdown, vendor comparison, crafted reagents, shopping list) per `plan/FEATURES.md`.
