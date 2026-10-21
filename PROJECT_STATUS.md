# Project status

Read this after CLAUDE.md at the start of every session. CLAUDE.md says how to build; this file says where things stand. Update it at the end of every milestone or when a decision is made. Keep it short: replace old status, do not append a diary.

Last updated: 2026-10-21

## Where we are

- Milestones 1, 2 and 3 are done and pushed, plus the turbo game clock, the tier 1 route limit, the 6-slot garage cap, selling and vehicle unlocks as rules (decisions below, rules and tests only, no screens). 296 tests pass, `flutter analyze` is clean. Economy config is version 0.4
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
- Selling: `settings.resaleShareOfPrice` = 0.6 (sheet: Settings row 28). `resaleValueTk` returns price x 0.6 rounded to whole Taka; `checkSale` rejects a vehicle on the road (`vehicleOnTheRoad`), so selling is unassign, let the trip finish, sell. Rule only, no selling screen yet. `swapPaybackHours` gives the real hours at 1x until the profit gain of a sale-and-swap earns back the resale loss (null if never)
- Unlocks are in the MVP, in the sheet (Vehicles columns R and V, new Operating Permits sheet) and in `economy.json` (`permits` table; per vehicle `unlockPermit` or `unlockDeliveries`, never both). Tiers 1, 2 and 4 are open at the start; tier 3 needs 5 deliveries (`Company.completedTrips`); Light operating permit: tier 5; Medium: tiers 6 and 7; Heavy: tiers 9, 11 and 12; Cold chain: tier 8; Hazmat: tier 10. `checkVehicleUnlocked` and `checkPermitPurchase` are in `lib/core/economy/unlock_rules.dart`
- Permits are one-time Taka purchases, never a premium currency (matches the no-paywall design rule). Confirmed prices: light Tk 4 lakh, medium Tk 5 lakh, cold chain Tk 7 lakh, hazmat Tk 8 lakh, heavy Tk 10 lakh (Tk 34 lakh in total). Each is about 15 to 17 percent of the cheapest vehicle it unlocks; on the sheet's typical routes that adds 1.9 to 5.5 real hours of payback at 1x and keeps every vehicle inside its target range (Operating Permits sheet, columns G to I)

Tech
- Storage: hive_ce and hive_ce_flutter (original hive unmaintained since 2022), manual TypeAdapters, no build_runner
- Crash safety: every save is a ChangeSet of absolute values, written first to the `pending_change` box, then applied, then cleared. Startup finishes any pending record
- Game clock = real time since company creation + turbo bonus. The bonus is a pure function of `Company.turboElapsed` (`TurboSchedule.bonusAt`: 19, 9 and 4 extra minutes per foreground minute in the three phases, 640 minutes in total), so there is no new Company field. Game days and demand resets run on this clock and speed up with the turbo. Background time adds no bonus, so offline progress is unchanged
- Because the bonus changes over time, a route's day cannot be recomputed from its timestamp. `RouteState.gameDay` (adapter field 3, optional) stores it; old saves without it fall back to the day of `updatedAt`
- A wait for the next day is exact when the boundary is already past; a boundary still ahead is shortened by the current turbo speed, and an early wake-up just waits again
- `lib/core/sim` imports the pure Dart data models (no Flutter, no Hive). Accepted
- Added fields: `Vehicle.availableAt`, `Trip.vehicleTier`, `Company.turboElapsed`, `RouteState.gameDay`. Config only: `vehicles[].allowedRoutes`, `vehicles[].unlockPermit`, `vehicles[].unlockDeliveries` (replaced the free-text `unlock`), `permits`, `settings.startingGarageSlots`, `settings.resaleShareOfPrice`

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
4. **The cap fills early and cash piles up; selling and permits are partial sinks.** The tier 1 limit and the cap end the runaway (before: 166 vans, Tk 60 lakh in hour 1; then 43 Bijli Cargos, Tk 97 lakh). Buyers reach the 6 slots between minute 0 and 59 and A and D hold Tk 38 to 41 lakh of idle cash at hour 3. Policy D beats A on every measure, so cheapest-first is not the best play. Policy E (selling at 0.6) turns the idle cash into upgrades: Tk 59.4 lakh income against D's 42.6, and Tk 6.2 lakh against 3.2 in hour 3. But every swap loses 40% of the sold price, so at resale value E ends behind D (Tk 48.1 against 58.8 lakh); it would catch up after about 3.6 more hours at 1x (loss Tk 10.7 lakh over a gain of about Tk 3 lakh an hour). Resale 0.5 or 0.7 moves that gap to Tk 17.1 or 6.4 lakh and the income lead stays. Selling pays off over hours, not in the first hour. Permits (proposed Tk 34 lakh in total) are the other sink, about the size of A's and D's idle cash, but the bots do not buy them. Still open for Milestone 5: price slot expansion and the first terminal (Tk 8 lakh) so cash has somewhere to go, then rerun the tool

## Known gaps (fix before release, not now)

- R07 (Dhaka to Sylhet) has crossing "None", so no toll. The real road passes the Bhairab Bridge toll plaza. Verify the toll and add it to the sheet's Tolls table and the R07 crossing. R07 has the shortest payback of any route for tiers 4 to 12 (payback_by_tier tool), so this moves payback for most vehicles; tiers 9 and 10 already sit just below their 20 hour target minimum on R07
- The sheet's First Hour tab ignores demand and the garage cap. `tool/first_hours_sim.dart` is the pacing check until the sheet is updated
- Route distances are approximate. Replace with real road distances (OSRM) during data prep
- Meghna+Gumti and Paturia ferry tolls are partly estimated. Re-verify all tolls, diesel price and truck prices before release
- Placeholder screen has inline English strings (moves to ARB in Milestone 7)
- `Company.permits` (adapter field 5, optional, default empty) exists, but a permit purchase is not yet part of `ChangeSet`. Add `permitsAfter` to `ChangeSet` with the buy screen (Milestone 4), so buying a permit is crash safe like every other save. Committing a change already keeps the owned permits
- Deferred fields: fitness certificate expiry, terminal level, checklist progress (add with defaults in their milestones)
- The pacing tool's bots buy no permits, so tiers 5 and up are never tested for pacing. Add permit buying to the bots when tier 5 and up matter (Milestone 5 or later)

## Tooling notes

- Claude Code on Windows: interactive commands (like `flutter doctor --android-licenses`) do not work with `!`. Run them in a separate terminal tab
- Heredocs fail in the Windows shell. Write scripts to a file, then run them
- `dart run tool/first_hours_sim.dart [hours] [seeds] [policies] [resale]` simulates the first hours with the real sim code and prints the pacing figures used in the open questions (policies A to E, default all; the optional last argument overrides the resale share in memory for a sensitivity run)
- `dart run tool/payback_by_tier.dart` prints payback per tier on its best route, the same definition as the sheet
- PowerShell 5.1 `Set-Content -Encoding utf8` adds a BOM. Edit JSON and source files with the editor tools, or strip the BOM afterwards
- Use high effort (`/effort`) for milestone work
