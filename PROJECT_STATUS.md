# Project status

Read this after CLAUDE.md at the start of every session. CLAUDE.md says how to build; this file says where things stand. Update it at the end of every milestone or when a decision is made. Keep it short: replace old status, do not append a diary.

Last updated: 2026-10-22

## Where we are

- Milestones 1, 2 and 3 are done, plus the turbo game clock, the tier 1 route limit, the 6-slot garage cap, selling, vehicle unlocks and operating permits as rules, and `Company.permits` (decisions below). 523 tests pass, `flutter analyze` is clean. Economy config is version 0.4
- Milestone 4 is in progress: steps 1 to 7 (and 5b, 7b) are done (see the step list below). The app runs: new-game screen, then the shell (header with company, cash and turbo badge; Map, Garage, Finance, Settings). The garage lists the vehicles with a temporary "Start working" button; map, finance and settings are placeholders
- Balance work is paused until Milestone 5 (see open question 4)
- Next: step 8, engine: selling and the swap hint, trip pruning

## Milestones

| # | Milestone | Status |
|---|---|---|
| 1 | Config loader, economy engine, golden tests | Done |
| 2 | Data models, Hive adapters, repositories | Done |
| 3 | Clock, turbo, dispatch, settlement, offline catch-up, crash safety | Done |
| 4 | Screens: map, garage, buy with demand preview, assign route, finance. Also: selling with a swap hint from `swapPaybackHours`, permit purchase through `ChangeSet` (`permitsAfter`), the garage slot count on the buy screen | In progress |
| 5 | Terminals, demand regeneration, overload slider, fitness timer | |
| 6 | Events and checklist | |
| 7 | Localization review (Bangla translations), notifications, polish, Android release | |
| 8 | Windows build and installer | |

### Milestone 4 steps

Each step ends with `flutter analyze` and `flutter test` passing, and one commit.

| Step | What | Status |
|---|---|---|
| 1 | Wire engine and game loop into the app with Provider (`bootstrap`, `VehicleManagerApp`). Desktop rule: `resumed` and `inactive` count turbo time, only `hidden`, `paused` and `detached` freeze it | Done |
| 2 | Read model `GameEngine.snapshot`, `vehicleActivity`, `UiClock` (one second) | Done |
| 4 | ARB (en, bn), `Formats` (lakh and crore, Bangla digits), `AppSettings` (language, theme) in a device settings box | Done |
| 3 | `settings.starterVehicleTier`, free starter vehicle, new-game screen, read-only vehicle list on the temporary home | Done |
| 5 | Responsive shell: bottom bar under 600 px, rail and detail panel from 600 px | Done |
| 5b | Medium layout: rail and full-width page from 600 to 840 px, map and side panel only from 840 px | Done |
| 6 | `route_economics.dart` in core for the demand preview (moved from the tools) | Done |
| 7 | Engine: buy vehicle, buy permit. `ChangeSet` gets `permitsAfter` and `removedVehicleIds`. Settlement `ChangeSet` also updates lifetime totals and the per-game-day rollup | Done |
| 7b | Every engine operation finishes a half-written save before reading state (no double payment while the app keeps running) | Done |
| 8 | Engine: selling (unassign, wait, sell) and the swap hint from `swapPaybackHours`. Prune settled trips older than the last 500 only after they are counted | Next |
| 9 | Garage screen and vehicle detail | |
| 10 | Assign route and cargo (removes the temporary button) | |
| 11a | Buy screen, static: tiers, locks, slot count, demand preview | |
| 11b | Buy screen, interaction: buy vehicle, buy permit | |
| 12a | Map screen, static: `assets/config/map_layout.json`, cities, routes, vehicles | |
| 12b | Map screen, interaction: pan, zoom, wheel, tap a route | |
| 13 | Finance screen from the rollups | |
| 14 | Settings screen: language, theme, new game with confirmation | |
| 15 | Closing pass: wide layout, dark theme, touch targets, manual runs on Windows and Android | |

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
- Selling: `settings.resaleShareOfPrice` = 0.6 (sheet: Settings row 28). `resaleValueTk` returns price x 0.6 rounded to whole Taka; `checkSale` rejects a vehicle on the road (`vehicleOnTheRoad`), so selling is unassign, let the trip finish, sell. Rule only, no selling screen yet. `swapPaybackHours` gives the real hours at 1x until the profit gain of a sale-and-swap earns back the resale loss (null if never)
- Unlocks are in the MVP, in the sheet (Vehicles columns R and V, new Operating Permits sheet) and in `economy.json` (`permits` table; per vehicle `unlockPermit` or `unlockDeliveries`, never both). Tiers 1, 2 and 4 are open at the start; tier 3 needs 5 deliveries (`Company.completedTrips`); Light operating permit: tier 5; Medium: tiers 6 and 7; Heavy: tiers 9, 11 and 12; Cold chain: tier 8; Hazmat: tier 10. `checkVehicleUnlocked` and `checkPermitPurchase` are in `lib/core/economy/unlock_rules.dart`
- Permits are one-time Taka purchases, never a premium currency (matches the no-paywall design rule). Confirmed prices: light Tk 4 lakh, medium Tk 5 lakh, cold chain Tk 7 lakh, hazmat Tk 8 lakh, heavy Tk 10 lakh (Tk 34 lakh in total). Each is about 15 to 17 percent of the cheapest vehicle it unlocks; on the sheet's typical routes that adds 1.9 to 5.5 real hours of payback at 1x and keeps every vehicle inside its target range (Operating Permits sheet, columns G to I)

Tech
- Gradle wrapper stays on 8.14 (debug APK builds, checked 2026-10-22). Gradle 9.6 and up break the build with AGP 8.11.1, which uses a Gradle internal API removed in 9.6. Upgrade AGP before Gradle
- Storage: hive_ce and hive_ce_flutter (original hive unmaintained since 2022), manual TypeAdapters, no build_runner
- Crash safety: every save is a ChangeSet of absolute values, written first to the `pending_change` box, then applied, then cleared. Startup finishes any pending record, and so does every engine operation before it reads state (`GameEngine._serial`), so a commit that throws while the app keeps running is finished before anything is computed from the save. Tested for a payout and a purchase failing after every commit step
- Game clock = real time since company creation + turbo bonus. The bonus is a pure function of `Company.turboElapsed` (`TurboSchedule.bonusAt`: 19, 9 and 4 extra minutes per foreground minute in the three phases, 640 minutes in total), so there is no new Company field. Game days and demand resets run on this clock and speed up with the turbo. Background time adds no bonus, so offline progress is unchanged
- Because the bonus changes over time, a route's day cannot be recomputed from its timestamp. `RouteState.gameDay` (adapter field 3, optional) stores it; old saves without it fall back to the day of `updatedAt`
- A wait for the next day is exact when the boundary is already past; a boundary still ahead is shortened by the current turbo speed, and an early wake-up just waits again
- `lib/core/sim` imports the pure Dart data models (no Flutter, no Hive). Accepted
- Added fields: `Vehicle.availableAt`, `Trip.vehicleTier`, `Company.turboElapsed`, `RouteState.gameDay`, `Company.lifetimeRevenue` and `lifetimeCosts` (adapter fields 6 and 7, default zero), `ChangeSet` fields 5 to 9 (`permitsAfter`, `removedVehicleIds`, `lifetimeRevenueAfter`, `lifetimeCostsAfter`, `dayRollups`; absent in an old pending record means unchanged). New model `DayRollup` (type id 7) in its own `day_rollups` box. Config only: `vehicles[].allowedRoutes`, `vehicles[].unlockPermit`, `vehicles[].unlockDeliveries` (replaced the free-text `unlock`), `permits`, `settings.startingGarageSlots`, `settings.resaleShareOfPrice`

Milestone 4
- All user text is in ARB from the start (`lib/l10n`, built-in gen-l10n, no new package). Vehicle, route and cargo names are ARB select messages keyed by tier, route id and camel-cased cargo name; `test/l10n/config_names_test.dart` fails if the config gains one without a translation. Milestone 7 is the Bangla review, not the first translation
- Device settings (language, theme) live in their own Hive box that a new game does not erase. Language null follows the device, English is the fallback
- `settings.starterVehicleTier` = 4 (sheet: Settings row 29). The starter is granted by `startNewGame`, unassigned. The company is written last, so a half-made game looks like no game
- No new packages: plain Navigator, no go_router. The map layout goes in `assets/config/map_layout.json`, not in `economy.json` (it is not economy data)
- Demand preview economics live in `lib/core/economy/route_economics.dart`: `RouteEconomics` (profit per real hour at 1x, tons per game day, payback, how many of the vehicle a route holds), `bestCargoOn` and `bestCargoPerRoute` (the cargo with the highest profit per hour), and `RouteDemand` (spare demand against the fleet's tons per game day, `fits`, `vehiclesThatFit`). Legal payload, expected fines and accidents, the sheet's payback definition. Both tools use it, so the pacing figures and the buy screen share one formula; their output was unchanged by the move. A game day is 24 game hours (`gameHoursPerDay`)
- Buying (step 7): `GameEngine.buyVehicle(tier)` and `buyPermit(id)` each save one `ChangeSet` through the committer, so a purchase is crash safe like a settlement. A vehicle arrives unassigned. `checkVehiclePurchase` (core) refuses in the order the buy screen explains: locked (permit or deliveries), then a full garage, then cash. A refusal saves nothing and does not notify. Buying with no game throws a `StateError`
- Settlement totals: every settled trip adds to `Company.lifetimeRevenue` and `lifetimeCosts` (a `TripCosts`, so the finance screen can split costs by part) and to the `DayRollup` of the game day it arrived in (`GameCalendar.dayIndex`, with the turbo bonus). Both are absolute values in the same `ChangeSet` as the payout. The simulator reads saved rollups through `SimWorld.rollupOf`, a lookup, so the history is never copied per tick. Vehicle and permit purchases are not in the rollups (they are spending, not trip results)
- The overload slider stays out of M4 (assign uses 0 overload). Trip history: keep the last 500 settled trips, plus lifetime totals on `Company` and a per-game-day rollup (revenue, costs, trips) for the finance screen, both updated inside the settlement `ChangeSet`; pruning only deletes trips that are already counted
- Shell (`lib/ui/shell/app_shell.dart`): four places, Map, Garage, Finance, Settings (`ShellDestination`). Three layouts by `WindowClass`, breakpoints `Layout.mediumBreakpoint` (600) and `Layout.expandedBreakpoint` (840) in `lib/ui/layout.dart`. Compact (under 600): the page fills the body with a bottom bar. Medium (600 to 839): a rail, and the selected page fills the area beside it, the map too when selected; no side panel. Reason: at 600 px a map beside a panel got about 200 px. Expanded (840 and up): a rail, the map in the main area, and the selected page in a side panel: half the area beside the rail, 320 to 400 px, but no wider than leaves the map `Layout.mapMinWidth` (360 px) (`Layout.sidePanelWidth`). Neither is ever shrunk below its minimum: when a wide rail (long Bangla labels, large text scale) leaves less than 681 px beside it (`Layout.mapAndPanelFit`), the expanded layout shows the medium content instead (rail, page fills the area, no panel). Choosing Map closes the panel. One selection for all three layouts, so a resize across either breakpoint keeps the page. CLAUDE.md (Platforms) describes the same three layouts. The header on every page shows company, cash and a turbo badge (only while the speed is above 1). The start page is the garage until the map is built in step 12. Pages have no Scaffold of their own. Icons are Flutter's built-in outlined Material icons (no icon package)
- Widget tests that use the save go through `test/support/app_harness.dart`: the save is real file IO, so setup runs in `runAsync`, every later engine operation stays in the test zone, and `settle` pumps until `engine.isBusy` is false. Mixing the two zones deadlocks inside Hive

Product
- Android first, Windows second, no web in the MVP
- Design system: Lal Sabuj, mirrored in `lib/ui/theme/`
- Repo: github.com/gitsifat091/vehicle-manager-bd, synced to the Claude project "Vehicle Manager Bangladesh"

## Open questions

All figures below come from `dart run tool/first_hours_sim.dart 3 20 ABDE` (3 hours, default config, 6 garage slots, resale 0.6, 20 seeds, foreground play, Local hauls from Dhaka only, unlock rules applied but the bots buy no permits, medians). Rerun it after any balance change. The sheet's First Hour tab scales income by turbo speed and ignores demand, the slot cap and unlocks (a day is 24 real minutes at 1x). The game matches the first part, because days and trips speed up together.

Policies: A buys the cheapest useful vehicle (all tiers), B the cheapest from tier 3 up, D the affordable one with the highest profit per real hour (all tiers), E is D plus selling: with a full garage it unassigns the worst vehicle (by profit per hour) when a better one is then affordable, sells it once its trip has settled and buys the better one.

| | A | B | D | E |
|---|---|---|---|---|
| Purchases in hour 1 | 5 | 5 | 5 | 11 |
| Hour 1 income (Tk lakh) | 23.9 | 38.6 | 36.1 | 47.5 |
| Hour 2 income (Tk lakh) | 2.1 | 5.3 | 3.2 | 5.7 |
| Minute the cap is reached | 0 | 59 | 1.5 | 1.5 |
| Bought | 2 Sonar Van, 3 Bijli Cargo | 1 Sathi Plus, 4 Tuntuni Mini | 1 Sathi Plus, 2 Bijli Cargo, 2 Sonar Van | 2 Sonar Van, 4 Bijli Cargo, 4 Tuntuni Mini, 3 Sathi Plus |
| Sold | 0 | 0 | 0 | 8 (2 Sonar Van, 4 Bijli Cargo, 2 Tuntuni Mini) |
| In the fleet at the end (with the starter) | 2 Sonar Van, 3 Bijli Cargo, 1 Sathi Plus | 4 Tuntuni Mini, 2 Sathi Plus | 2 Sonar Van, 2 Bijli Cargo, 2 Sathi Plus | 2 Tuntuni Mini, 4 Sathi Plus |
| Total income, 3 h (Tk lakh) | 28.0 | 49.2 | 42.6 | 59.4 |
| Cash at end (Tk lakh) | 38.1 | 11.2 | 41.2 | 5.2 |
| Net worth, vehicles at price (Tk lakh) | 56.0 | 77.2 | 70.6 | 76.9 |
| Net worth, vehicles at resale value (Tk lakh) | 48.8 | 50.8 | 58.8 | 48.1 |

1. **Post-turbo income gap.** Policy B earns Tk 38.6 lakh in hour 1 (sheet: about 25 lakh), then Tk 5.3 lakh in hour 2. With the unlock rules B buys a Sathi Plus first (tier 3 is locked until 5 deliveries) and fills the 6 slots at a median of minute 59, so the limit after the turbo is slots, not cash: in 13 of 20 seeds B cannot buy anything after minute 60 and holds Tk 11 lakh at hour 3. Plan a checklist reward around the 1 to 2 hour mark (Milestone 6); a free garage slot or a discount on the first terminal would fit
2. Overloading on routes with no weighbridge is very profitable (2.3x). Plan a random mobile-check event (Milestone 6)
3. **R01 demand.** One Sathi Plus on R01 moves 25.7 t per game day at any speed, so R01 (60 t a day) holds two of them plus a small van, and a third pickup waits for the next day. Under the 6-slot cap policies A and B never run R01 dry; policy D does at minute 80 (a Sathi Plus parcel van and two Bijli Cargos beside the starter), but not in the last hour. No pacing change needed. The sheet only checks this statically ("vehicles before demand runs out")
4. **The mid-game depends on terminals. Balance work is paused until Milestone 5.** The tier 1 limit and the 6-slot cap ended the runaway (before: 166 vans, Tk 60 lakh in hour 1; then 43 Bijli Cargos, Tk 97 lakh). The 3-hour table above shows cheapest-first (A) is not the best play and selling (E) trades resale loss for income. Six-hour medians (`dart run tool/first_hours_sim.dart 6 20 BEFGH`, Tk lakh):
   - **B** (cheapest, tier 3 up): income 38.6 in hour 1, then a flat 5.3 an hour. The garage is full at minute 59 and nothing is bought for the next 5 hours (longest stretch 301 minutes), leaving 26.1 idle at hour 6. Its cash passes the Tk 8 lakh first terminal at about hour 2.4 (5.9 after hour 2, growing about 5 an hour)
   - **E** (sells and upgrades): income 47.5, 5.7, 6.2, 6.6, 7.2 and 8.0 by hour, 11 sales, cash held at 3 to 6, a purchase or sale about every 74 minutes. Total income 80.2 against B's 64.1, but net worth at resale value 53.2 against B's 65.7
   - **F** (E plus permits) bought no permit and equals E. On the Dhaka Local routes no permit-locked vehicle beats the worst one, because large vehicles do not fit them (a Pahari Tipper holds 0.0 to 0.8 per Local route)
   - **With Line hauls** (diagnostic G = E, H = F, an attentive player): total income 109.5 and 110.1. G stalls from hour 4 with 36 idle. H buys one permit (Light) and one Meghna 14 and ends lower in net worth at resale value (65.7 against 82.5)
   - **Conclusion:** selling and permits do not carry the mid-game on Local routes. Large vehicles and Line hauls need terminals. In Milestone 5, validate the mid-game with a terminal-buying policy in the tool, and price terminals and slot expansion for the idle cash. No balance number changes until then

## Known gaps (fix before release, not now)

- R07 (Dhaka to Sylhet) has crossing "None", so no toll. The real road passes the Bhairab Bridge toll plaza. Verify the toll and add it to the sheet's Tolls table and the R07 crossing. R07 has the shortest payback of any route for tiers 4 to 12 (payback_by_tier tool), so this moves payback for most vehicles; tiers 9 and 10 already sit just below their 20 hour target minimum on R07
- The sheet's First Hour tab ignores demand and the garage cap. `tool/first_hours_sim.dart` is the pacing check until the sheet is updated
- Route distances are approximate. Replace with real road distances (OSRM) during data prep
- Meghna+Gumti and Paturia ferry tolls are partly estimated. Re-verify all tolls, diesel price and truck prices before release
- The garage's "Start working" button (R01, General dry hardcoded) is temporary: the assign screen replaces it in step 10. Map, finance and settings are `ComingLater` placeholders until steps 12 to 14
- `DayRollup` records are never pruned: one per game day with a settled trip, about 60 a real day at 1x (a few kB each day, all loaded by Hive). Decide in step 8, with trip pruning, whether to keep them all or cap them
- Deferred fields: fitness certificate expiry, terminal level, checklist progress (add with defaults in their milestones)
- The pacing tool's bots buy no permits, so tiers 5 and up are never tested for pacing. Add permit buying to the bots when tier 5 and up matter (Milestone 5 or later)

## Tooling notes

- Claude Code on Windows: interactive commands (like `flutter doctor --android-licenses`) do not work with `!`. Run them in a separate terminal tab
- Heredocs fail in the Windows shell. Write scripts to a file, then run them
- `dart run tool/first_hours_sim.dart [hours] [seeds] [policies] [resale]` simulates the first hours with the real sim code and prints the pacing figures used in the open questions (policies A to H, default all; the optional last argument overrides the resale share in memory for a sensitivity run)
- `dart run tool/payback_by_tier.dart` prints payback per tier on its best route, the same definition as the sheet (both tools use `route_economics.dart`)- PowerShell 5.1 `Set-Content -Encoding utf8` adds a BOM, and `Get-Content -Raw` reads UTF-8 as ANSI, which corrupts Bangla text when the file is written back. Edit source, JSON and test files with the editor tools, or use `[IO.File]::ReadAllText` and `WriteAllText` with a UTF-8 encoding without a BOM
- `lib`, `test` and `tool` are `dart format` clean, so formatting any file or the whole tree only changes what you edited
- Hive in widget tests: see `test/support/app_harness.dart` (Milestone 4 decisions above)
- Use high effort (`/effort`) for milestone work
