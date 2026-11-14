# Brief for the next session (written 2026-11-13, end of the first long session)

Read this first, then `plan/FEATURES.md` and `plan/DESIGN.md`. Project-wide rules are in `/home/user/Dev/Gaming/Blizzard/AGENTS.md`; Forever facts in `knowledge/forever-vs-vanilla.md`.

## Where things stand
- ProfitCraft is public at github.com/PsiGaming/ProfitCraft (MIT). Released as GitHub pre-releases: 0.1-alpha.0, alpha.1, alpha.2, alpha.3, alpha.4 (alpha.4 = own disenchant estimate). Sylice and friends install via WowUp. Zip name `ProfitCraft-v<version>-forever.zip`, built with `git archive --prefix=ProfitCraft/` (the `plan/` folder is excluded via `.gitattributes`).
- Everything Sylice reported after testing alpha.0-alpha.2 is fixed; disenchant values are rebuilt for alpha.4 (below).
- Version scheme: Sylice decides when a version number changes. Don't publish without Sylice's go-ahead.

## Current state: 0.1-alpha.5, published 2026-11-14 as a GitHub pre-release; all of it confirmed working in game by Sylice (2026-11-14)
- alpha.4 (own disenchant estimate, `Disenchant.lua`, DESIGN.md section 12) is published and confirmed working in game by Sylice.
- alpha.5 adds: the disenchant tooltip lists what the item can disenchant into (always shown; Sylice: keep it so); trainer and recipe item tooltips with reagent cost, AH price, profit per craft and craft-and-disenchant (`UI/RecipeTooltip.lua`); bind-on-pickup products get no sale profit anywhere (tooltips, side panel "BoP", recipe details), craft-and-disenchant still shown.
- Forever facts behind the tooltips: PsiLab 0.1-alpha.2 results, `data/psilab/PsiLab-2026-11-14-alpha2-trainer.lua`, written up in `knowledge/forever-vs-vanilla.md`. Unchecked: recipes of professions the character doesn't have.
- Test harness: 84 checks pass.
- **0.1-beta.0 published 2026-11-14** (GitHub pre-release; Sylice: the addon works well enough to leave alpha). So far: price warning banner in the side panel (Auctionator missing / no prices / prices too old) and a settings slider for the age (Off, 1-4 days, default 2); 99 checks pass. Not yet seen in game: the banner and the slider.
- **Next changes built (planned as 0.1-beta.1)**, committed with the version left at **0.1-beta.0** on purpose: Sylice's experiment (2026-11-14) to see whether WowUp offers an update when a release is replaced but the version/zip name stays the same. Expected (WowUp source): no update notice. Afterwards the version goes to beta.1. Contents: per-reagent lines with "(AH)" / "(Vend)" in front of each amount in the trainer/recipe tooltips and recipe details, "AH price" renamed "Auction price". 101 checks pass.
- Betas: fixes only; new features go to 0.2. Published as GitHub pre-releases like the alphas; the final 0.1 is the first normal release.

## How we work
- Evidence for Forever API facts: Blizzard's Forever UI source (Gethe/wow-ui-source, branch `forever`; shallow clone ~54 MB into /tmp) and PsiLab results; reference addons are idea sources, not proof.
- Tests: LuaJIT via `lupa` in a temp venv (`uv venv /tmp/luachk && uv pip install --python /tmp/luachk/bin/python lupa`) with stubbed WoW functions. The test harness lived in `/tmp/pcraft-test/` (`harness.lua`, `run.py`) and will be gone after a reboot; recreate it rather than skipping tests (it simulated login, opening a profession, prices from a fake Auctionator, all windows and settings; 64 checks at alpha.3).
- Sylice reviews uncommitted changes in Claude Code's `/diff` (open Claude Code in the addon's folder). New files: `git add -N`.
- Files Sylice sends arrive in `~/QubesIncoming/<qube>/`: **move** them out immediately (leftovers block the next transfer). PsiLab results go to `data/psilab/`, screenshots to `data/screenshots/`.
- Sylice can't read Lua; explain changes in plain words, keep answers short and concrete.

## Other open items (not urgent)
- `GetAuctionAgeByItemID` unit (whole days?): run PsiLab `/lab run` a day after a scan.
- Whether Blizzard's free-bag-space number also counts the reagent bag.
- Shorten the reagent-bag checkbox hover text (it still tells people to use Blizzard's Interface option, now duplicated by the checkbox above it): suggested, not yet approved.
- Sylice mentioned "the shopping list works well" though ProfitCraft has none yet; never clarified (probably meant D/E Bags or Auctionator's list).
- Milestone 0.2 (own AH scan, standalone) and 0.3 (filters, hover breakdown, vendor comparison, crafted reagents, shopping list) per `plan/FEATURES.md`.
