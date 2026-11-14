# Brief for the next session (written 2026-11-13, end of the first long session)

Read this first, then `plan/FEATURES.md` and `plan/DESIGN.md`. Project-wide rules are in `/home/user/Dev/Gaming/Blizzard/AGENTS.md`; Forever facts in `knowledge/forever-vs-vanilla.md`.

## Where things stand
- ProfitCraft is public at github.com/PsiGaming/ProfitCraft (MIT). Released as GitHub pre-releases: 0.1-alpha.0, alpha.1, alpha.2, alpha.3 (alpha.3 published at the end of this session). Sylice and friends install via WowUp. Zip name `ProfitCraft-v<version>-forever.zip`, built with `git archive --prefix=ProfitCraft/` (the `plan/` folder is excluded via `.gitattributes`).
- Everything Sylice reported after testing alpha.0-alpha.2 is fixed, **except disenchant values** (see below).
- Version scheme: Sylice decides when a version number changes. Don't publish without Sylice's go-ahead.

## Next task: disenchant values
Full findings and plan: `plan/DESIGN.md` section 12. Short version:
- Auctionator's disenchant API returns nothing on Forever (its D/E support covers only later expansions). Sylice decided: no separate addon; ProfitCraft builds its own estimate.
- Approach: own disenchant table (quality × armor/weapon × level → materials, chance, quantity), priced with Auctionator's AH prices. Disenchant Buddy (`addons/reference/DisenchantBuddy`, GPLv3) shows the approach works but treats Forever as Classic; study it, never copy its code.
- First open question: item level vs required level. Settle with Sylice's Enchanting alt, ideally by adding a disenchant recorder module to PsiLab (`addons/dev/PsiLab`, public at PsiGaming/PsiLab).

## How we work
- **Never read Auctionator's code** (its authors asked AI tools not to; Sylice asked me to anyway and I declined). Use only its public API (`Auctionator.API.v1.*`) and in-game tests. Don't bring the subject up in plan documents.
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
