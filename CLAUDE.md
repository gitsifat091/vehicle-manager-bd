# Vehicle Manager Bangladesh

A Truck Manager style logistics tycoon set in Bangladesh, built in Flutter. The player buys vehicles, assigns them to real routes (Dhaka, Chattogram Port, Gazipur, Bogura and so on), waits for trips to finish in real time, and reinvests. Authenticity comes from real Bangladesh numbers: diesel price, bridge tolls, truck prices, overloading, ferries and seasonal events.

Solo developer project. Keep scope small and ship a playable single-player MVP first.

## Source documents (read before big design changes)

- `docs/research/truck-manager-analysis.md`: how Truck Manager works and the MVP feature list
- `docs/research/bangladesh-vehicle-types.md`: vehicle tiers, prices, tolls, fuel, regulations (Bangla)
- `docs/economy_model.xlsx`: the economy model. It is the source of truth for every number and formula
- `assets/config/economy.json`: the same numbers exported for the game. Never hardcode a balance value in Dart

## Tech stack (keep consistent)

- Flutter, Dart, null safety, Material 3
- State: Provider (ChangeNotifier)
- Storage: Hive with manual TypeAdapters. No build_runner, no code generation
- Offline-first. No backend, no login and no network calls in the MVP
- Map: a stylized schematic Bangladesh map drawn with CustomPainter (cities as nodes, routes as lines). No tile server in the MVP
- Localization: flutter_localizations + intl with ARB files (`app_bn.arb`, `app_en.arb`). Bangla font: Hind Siliguri or Noto Sans Bengali

## Design system: Lal Sabuj

The UI uses Lal Sabuj, Sifat's Bangladesh-themed design system (flag green, flag red, turmeric gold on a rice-paper neutral). Its tokens are mirrored in `lib/ui/theme/`:

- `lal_sabuj_tokens.dart`: colours (light and dark), `Space`, `Radii`, `Fonts`
- `app_theme.dart`: `AppTheme.light` and `AppTheme.dark`, plus `GameText` (tabular numbers) and `AppButtons.danger`
- `game_colors.dart`: the game layer as a `ThemeExtension` (map land and rivers, route states, terminals, money gain and loss, demand bars, trip progress, turbo badge)

Rules:

- Never write a hex colour, font size or padding number in a widget. Use `Theme.of(context)`, `GameColors`, `Space` and `Radii`
- Green leads, red punctuates. `lal` (flag red) appears at most once per view: the logo disc or one big numeral. Errors, fines and losses use `error` (lal-strong), never a full red fill
- Destructive actions (sell vehicle, close terminal) use `AppButtons.danger`, an outlined button
- Text on a fill uses its matching on-colour (`onPrimary`, `onSecondary`)
- No gradients, no heavy shadows. Separate surfaces with `surfaceContainer` and dividers
- Touch targets at least 44 px tall
- Bangla text: never below 14 px, no letter-spacing, no all caps
- Money, counters and timers use `GameText.money` or `GameText.stat` so digits do not jump
- Rivers are the only blue in the game
- Icons: one outline icon set (Material Symbols Outlined) coloured with `onSurface` or `primary`. No emoji in the UI
- If a token changes in the Lal Sabuj design system, update `lal_sabuj_tokens.dart` to match

Fonts are bundled for offline use (download the .ttf files from Google Fonts, both are under the SIL Open Font License):

```yaml
flutter:
  fonts:
    - family: HindSiliguri
      fonts:
        - asset: assets/fonts/HindSiliguri-Regular.ttf
          weight: 400
        - asset: assets/fonts/HindSiliguri-Medium.ttf
          weight: 500
        - asset: assets/fonts/HindSiliguri-SemiBold.ttf
          weight: 600
    - family: AnekBangla
      fonts:
        - asset: assets/fonts/AnekBangla-Medium.ttf
          weight: 500
        - asset: assets/fonts/AnekBangla-SemiBold.ttf
          weight: 600
```

## Platforms

- Targets: Android first, Windows second. iOS, macOS and Linux are possible later from the same code
- No web build and no website in the MVP. A landing page with download links can come at release
- Saves are local to each device. Progress does not sync between phone and PC until cloud sync is added (post-MVP)
- Responsive from day one: use `LayoutBuilder` breakpoints. Below 600 px wide, use phone layout with bottom navigation. At 600 px and above, use a navigation rail with the map in the main area and a detail side panel instead of stretched phone screens
- Support mouse and keyboard on desktop: hover states, scroll wheel zoom on the map, right-click is optional
- Notifications: Android only in the MVP. Hide the notification settings on platforms that do not support them
- Keep platform-specific code behind small interfaces in `lib/platform/` so `lib/core/` stays pure Dart

## Folder layout

```
lib/
  core/
    economy/     pure Dart: fare, cost, toll, overload, payback formulas
    sim/         game clock, turbo start, trip lifecycle, offline catch-up
    config/      loads economy.json into immutable config classes
  data/
    models/      Vehicle, Route, Terminal, Trip, Company
    adapters/    hand-written Hive TypeAdapters
    repositories/
  state/         Providers
  ui/
    theme/       Lal Sabuj tokens, AppTheme, GameColors
    screens/     map, garage, vehicle detail, routes, finance, settings
    widgets/
  l10n/
  platform/      notifications and other platform-specific code behind interfaces
assets/config/economy.json
assets/fonts/
test/
docs/
```

Rule: `lib/core/**` must not import Flutter. It stays pure Dart so it can be unit tested quickly.

## Core formulas (must match the spreadsheet)

All money is an `int` in Taka. Round only when storing or displaying.

- Load carried = legal payload + overload, capped at the vehicle's max load
- Overload ratio = (load - legal payload) / legal payload
- Driven km = one-way km x 2 for Local hauls (return empty), one-way km for Line hauls
- Revenue = load x (baseFarePerTon + ratePerTonKm x one-way km) x cargo rateFactor x vehicle smallLoadPremium x freightMultiplier
- Energy = driven km x (diesel price / mileage, or otherEnergyTkPerKm if mileage is 0) x (1 + extraFuelPerFullOverload x overload ratio)
- Toll = toll table[vehicle tollClass][route crossing], doubled for Local hauls
- Trip time (game hours) = driven km / speed + load time + route extra delay
- Crew = trip time x crew wage per game hour
- Maintenance = driven km x maintenance per km x (1 + extraWearPerFullOverload x overload ratio)
- Overload fine: only if overloaded. Expected value = weighbridges x check chance x (fine base + fine per ton x tons over). In the game, roll each weighbridge separately
- Accident: chance = accidentChancePer100Km x driven km / 100 x (1 + growth x overload ratio). Cost = price x accidentCostShareOfPrice
- Profit = revenue - (energy + toll + crew + maintenance + fines + accident cost)

Golden test values (default config, no overload):
- Tier 6 Jamuna Open, R05 Dhaka to Chattogram Port, General dry: revenue 36,375, profit per trip 23,995 (expected values)
- Tier 4 Sathi Plus, R01 Dhaka city, General dry: revenue 2,693
If a code change breaks these, either the code is wrong or the spreadsheet must be updated first.

## Time model

- Store every trip as `{vehicleId, routeId, cargo, loadT, departAt, arriveAt, revenue, costs}` with real UTC timestamps
- Real duration = game hours x 60 / gameMinutesPerRealMinute / turbo speed at dispatch time
- Never run a per-frame simulation loop. Positions and progress are computed from timestamps, so offline progress is free
- On app open: settle every trip whose arriveAt has passed, in time order, then auto-redispatch Local hauls back to back (each new trip departs at the previous arriveAt). A per-vehicle step cap stops runaway catch-up; the rest finishes on the next ticks
- While the app is open a slow timer (about 3 seconds) settles due trips and redispatches Local hauls
- Turbo Start: 20x for the first 20 minutes of foreground play, 10x until 40, 5x until 60, then 1x (values from config). Only foreground time counts: it is stored in `Company.turboElapsed` and frozen when the app is paused
- A game day is 24 game hours (24 minutes of game clock at 60 game minutes per real minute), counted from the company's creation. The game clock is real time plus the Turbo Start bonus (`TurboSchedule.bonusAt(turboElapsed)`, 640 minutes in total with the default phases), so days and demand resets speed up with the turbo. Route demand resets to `dailyDemandT` at each day boundary, and `RouteState.gameDay` remembers the day. A vehicle that finds no demand waits for the next day; if less than a full load is left it carries what is left
- Fines and accidents are rolled at settlement, one roll per weighbridge then one for the accident, with an injected seeded `Random`. `lib/core` never calls `DateTime.now()`: it takes a `Clock`
- Crash safety: every save goes through `ChangeCommitter`. A `ChangeSet` of absolute values (new cash total, whole trips) is written first as the pending record, then applied, then cleared. On start the pending record is finished, so a trip is never paid twice or lost

## MVP scope

In: 6 vehicle tiers (Sonar Van, Tuntuni Mini, Sathi Plus, Meghna 14, Jamuna Open, Bongo Mover 40), the routes in economy.json, Local and Line hauls, terminals, daily demand per route, overload slider, fitness certificate timer, 4 events (Eid demand spike, monsoon slowdown, hartal closing N1, N1 tailback), checklist of 10 to 15 tasks, Bangla/English toggle, trip-complete notifications, demand preview before buying a vehicle.

Out (later): multiplayer, auctions, long-haul contracts, bus mode, waterways, ads and in-app purchases, cloud sync.

## Design rules

- Show route demand before the player buys a vehicle (top complaint about Truck Manager)
- Never put a paywall or premium currency inside the tutorial or checklist
- Turbo and boost prices never escalate
- Vehicle names are fictional (rivers, birds, animals). No real brand names or logos anywhere
- Line hauls are limited by `settings.maxLineHaulKm` in economy.json (400 in v0.2). Never hardcode the limit in Dart
- Cargo compatibility comes from `cargo.allowedTiers` in economy.json. A vehicle can only be assigned a cargo that lists its tier
- A vehicle with a non-empty `vehicles[].allowedRoutes` can only run those routes (tier 1 runs M01 and M02). Empty means any route
- The garage holds `settings.startingGarageSlots` vehicles (6, counting the free starter). A purchase with no free slot is rejected through `checkGarageSlot`. Never hardcode the number

## Writing and UI text rules

- All user-facing text goes in ARB files, never inline in widgets
- Never mix Bangla and English in the same sentence or string
- No em dashes in UI text, comments or docs
- Money format: lakh and crore grouping (for example ৳ ৩১,৬০,০০০ in Bangla, Tk 31,60,000 in English)

## Working style for Claude Code

- Read `PROJECT_STATUS.md` at the start of every session. Update it at the end of every milestone or decision: replace the old status, do not append a diary
- Work in small steps that each end with `flutter analyze` and `flutter test` passing
- Write unit tests for every function in `lib/core/economy` and `lib/core/sim` before wiring UI
- When a balance number needs to change, change the spreadsheet and economy.json, not the Dart code
- Ask before adding a new package

## Milestones

1. Config loader + economy engine + golden tests
2. Data models, Hive adapters, repositories, save and load
3. Game clock, turbo start, trip settle loop, offline catch-up
4. Screens: map, garage, buy vehicle with demand preview, assign route, finance
5. Terminals, demand regeneration, overload slider, fitness timer
6. Events and checklist
7. Localization, notifications, polish, Android release build
8. Windows build: test the wide layout, mouse input and save location, then package an installer
