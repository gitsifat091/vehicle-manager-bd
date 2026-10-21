# Project status

Read this after CLAUDE.md at the start of every session. CLAUDE.md says how to build; this file says where things stand. Update it at the end of every milestone or when a decision is made. Keep it short: replace old status, do not append a diary.

Last updated: 2026-10-21

## Where we are

- Milestones 1, 2 and 3 are done and pushed, plus the turbo game clock, the tier 1 route limit and the 6-slot garage cap (decisions below). 264 tests pass, `flutter analyze` is clean. Economy config is version 0.3
- The engine and game loop are not wired into the app yet. `main.dart` shows a placeholder screen
- Next: Milestone 4 (screens)

## Milestones

| # | Milestone | Status |
|---|---|---|
| 1 | Config loader, economy engine, golden tests | Done |
| 2 | Data models, Hive adapters, repositories | Done |
| 3 | Clock, turbo, dispatch, settlement, offline catch-up, crash safety | Done |
| 4 | Screens: map, garage, buy with demand preview, assign route, finance | Next |
| 5 | Terminals, demand regeneration, overload slider, fitness timer | |
| 6 | Events and checklist | |
| 7 | Localization, notifications, polish, Android release | |
| 8 | Windows build and installer | |

## Decisions made (do not reopen without a reason)

Economy and balance
- Freight multiplier 1.5x real fares. At 1.0 the first hour has only 2 purchases. Truck prices, diesel and tolls stay fully real
- Time scale: 1 game hour = 1 real minute (1 game day = 24 real minutes)
- Turbo Start: 20x, 10x, 5x over the first 60 minutes, counting foreground play time only
- Start: Tk 15 lakh cash plus one free Sathi Plus (tier 4)
- Line hauls capped by `settings.maxLineHaulKm` (400). Cargo compatibility comes from `cargo.allowedTiers`
- Overload means tons above the legal payload, capped at the vehicle's max load
- Tier 1 (Sonar Van) runs only M01 and M02, through `vehicles[].allowedRoutes` (empty list = any route; sheet: Vehicles column U). Tier 2 (Bijli Cargo) stays unrestricted. Reason: with R01 to R03 open, a buyer got about 166 vans in the first 12 minutes
- Garage cap: `settings.startingGarageSlots` = 6 (sheet: Settings row 27), counting the free Sathi Plus. `checkGarageSlot` in `lib/core/economy/purchase_rules.dart` rejects a purchase with no free slot (`noFreeGarageSlot`). No selling, and no slot expansion until terminals in Milestone 5. Reason: tier 2 alone compounded in turbo (43 Bijli Cargos in 24 minutes, Tk 97 lakh in hour 1); tier 3 pays back in 40 to 59 minutes at 20x, so only a cap on the count stops every tier

Tech
- Storage: hive_ce and hive_ce_flutter (original hive unmaintained since 2022), manual TypeAdapters, no build_runner
- Crash safety: every save is a ChangeSet of absolute values, written first to the `pending_change` box, then applied, then cleared. Startup finishes any pending record
- Game clock = real time since company creation + turbo bonus. The bonus is a pure function of `Company.turboElapsed` (`TurboSchedule.bonusAt`: 19, 9 and 4 extra minutes per foreground minute in the three phases, 640 minutes in total), so there is no new Company field. Game days and demand resets run on this clock and speed up with the turbo. Background time adds no bonus, so offline progress is unchanged
- Because the bonus changes over time, a route's day cannot be recomputed from its timestamp. `RouteState.gameDay` (adapter field 3, optional) stores it; old saves without it fall back to the day of `updatedAt`
- A wait for the next day is exact when the boundary is already past; a boundary still ahead is shortened by the current turbo speed, and an early wake-up just waits again
- `lib/core/sim` imports the pure Dart data models (no Flutter, no Hive). Accepted
- Added fields: `Vehicle.availableAt`, `Trip.vehicleTier`, `Company.turboElapsed`, `RouteState.gameDay`

Product
- Android first, Windows second, no web in the MVP
- Design system: Lal Sabuj, mirrored in `lib/ui/theme/`
- Repo: github.com/gitsifat091/vehicle-manager-bd, synced to the Claude project "Vehicle Manager Bangladesh"

## Open questions

All figures below come from `dart run tool/first_hours_sim.dart 3 20 ABD` (3 hours, default config, 6 garage slots, 20 seeds, foreground play, Local hauls from Dhaka only, unlocks ignored, medians). Rerun it after any balance change. The sheet's First Hour tab scales income by turbo speed and ignores demand and the slot cap (a day is 24 real minutes at 1x). The game matches the first part, because days and trips speed up together.

Policies: A buys the cheapest useful vehicle (all tiers), B the cheapest from tier 3 up, D the affordable one with the highest profit per real hour (all tiers).

| | A | B | D |
|---|---|---|---|
| Purchases in hour 1 | 5 | 4 | 5 |
| Hour 1 income (Tk lakh) | 23.9 | 29.5 | 36.1 |
| Hour 2 income (Tk lakh) | 2.1 | 3.9 | 3.2 |
| Minute the cap is reached | 0 | 144 (none in 3 of 20) | 1.5 |
| Bought | 2 Sonar Van, 3 Bijli Cargo | 5 Tuntuni Mini | 1 Sathi Plus, 2 Bijli Cargo, 2 Sonar Van |
| Total income, 3 h (Tk lakh) | 28.0 | 37.8 | 42.6 |
| Cash at end (Tk lakh) | 38.1 | 4.6 | 41.2 |

1. **Post-turbo income gap.** Policy B (the player who buys slowly) earns Tk 29.5 lakh in hour 1 (sheet: about 25 lakh), then Tk 3.9 lakh in hour 2. Its next purchase after the turbo ends comes after a median of 84 minutes (range 59 to 118; none within 3 hours in 3 of 20 seeds). Policies A and D have no gap because they hit the cap in the first two minutes, but then they have nothing to spend on (see question 4). Plan a checklist reward around the 1 to 2 hour mark (Milestone 6)
2. Overloading on routes with no weighbridge is very profitable (2.3x). Plan a random mobile-check event (Milestone 6)
3. **R01 demand.** One Sathi Plus on R01 moves 25.7 t per game day at any speed, so R01 (60 t a day) holds two of them plus a small van, and a third pickup waits for the next day. Under the 6-slot cap policies A and B never run R01 dry; policy D does at minute 80 (a Sathi Plus parcel van and two Bijli Cargos beside the starter), but not in the last hour. No pacing change needed. The sheet only checks this statically ("vehicles before demand runs out")
4. **The cap fills in the first minutes and cash piles up.** The tier 1 limit and the cap end the runaway (before: 166 vans, Tk 60 lakh in hour 1; then 43 Bijli Cargos, Tk 97 lakh). Cheap buyers now reach the 6 slots at minute 0 to 1.5 and hold Tk 38 to 41 lakh of unspent cash at hour 3 (policy B: Tk 4.6 lakh). Slot expansion and terminals (Milestone 5) are the cash sink, so price them for that: the first terminal is Tk 8 lakh and nothing else in the economy absorbs money yet. Policy D beats A on every measure (total income, net worth), so cheapest-first is not the best play. Check this again once slot expansion exists

## Known gaps (fix before release, not now)

- R07 (Dhaka to Sylhet) has crossing "None", so no toll. The real road passes the Bhairab Bridge toll plaza. Verify the toll and add it to the sheet's Tolls table and the R07 crossing. R07 has the shortest payback of any route for tiers 4 to 12 (payback_by_tier tool), so this moves payback for most vehicles; tiers 9 and 10 already sit just below their 20 hour target minimum on R07
- The sheet's First Hour tab ignores demand and the garage cap. `tool/first_hours_sim.dart` is the pacing check until the sheet is updated
- Route distances are approximate. Replace with real road distances (OSRM) during data prep
- Meghna+Gumti and Paturia ferry tolls are partly estimated. Re-verify all tolls, diesel price and truck prices before release
- Placeholder screen has inline English strings (moves to ARB in Milestone 7)
- Deferred fields: fitness certificate expiry, terminal level, checklist progress (add with defaults in their milestones)

## Tooling notes

- Claude Code on Windows: interactive commands (like `flutter doctor --android-licenses`) do not work with `!`. Run them in a separate terminal tab
- Heredocs fail in the Windows shell. Write scripts to a file, then run them
- `dart run tool/first_hours_sim.dart [hours] [seeds] [policies]` simulates the first hours with the real sim code and prints the pacing figures used in the open questions (policies A to D, default all)
- `dart run tool/payback_by_tier.dart` prints payback per tier on its best route, the same definition as the sheet
- PowerShell 5.1 `Set-Content -Encoding utf8` adds a BOM. Edit JSON and source files with the editor tools, or strip the BOM afterwards
- Use high effort (`/effort`) for milestone work
