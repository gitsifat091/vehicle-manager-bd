# Project status

Read this after CLAUDE.md at the start of every session. CLAUDE.md says how to build; this file says where things stand. Update it at the end of every milestone or when a decision is made. Keep it short: replace old status, do not append a diary.

Last updated: 2026-10-21

## Where we are

- Milestones 1, 2 and 3 are done and pushed. The turbo game clock fix (decision below) is done on top of them. 251 tests pass, `flutter analyze` is clean
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

1. Post-turbo income gap: after the first hour the next purchase is about 2 hours away. Plan a checklist reward around the 1 to 2 hour mark (Milestone 6)
2. Overloading on routes with no weighbridge is very profitable (2.3x). Plan a random mobile-check event (Milestone 6)
3. With the faster turbo days, one pickup on R01 never runs out of demand in the first hour (about 500 trips, 29 game days), but a fleet of four does. Check the real first-hour pacing when the buy screen exists (Milestone 4), and tune the economy model if needed, not the Dart code

## Known gaps (fix before release, not now)

- Route distances are approximate. Replace with real road distances (OSRM) during data prep
- Meghna+Gumti and Paturia ferry tolls are partly estimated. Re-verify all tolls, diesel price and truck prices before release
- Placeholder screen has inline English strings (moves to ARB in Milestone 7)
- Deferred fields: fitness certificate expiry, terminal level, checklist progress (add with defaults in their milestones)

## Tooling notes

- Claude Code on Windows: interactive commands (like `flutter doctor --android-licenses`) do not work with `!`. Run them in a separate terminal tab
- Heredocs fail in the Windows shell. Write scripts to a file, then run them
- Use high effort (`/effort`) for milestone work
