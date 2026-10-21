# Decoding Truck Manager (Trophy Games / Xombat) and Adapting It for Bangladesh

Truck Manager is a server-based, real-time, map-driven logistics tycoon: you buy vehicles, place terminals in real cities, assign routes against daily demand, and keep wear, MOT and reputation under control, while a premium-currency, pack and subscription layer sells you time and access. A Bangladesh version can be built by a solo Flutter developer if it copies that loop but keeps the scope small: one country map, a handful of real corridors, BDT-denominated costs, and an offline-first or lightweight backend.

## TL;DR

- **How it works:** You earn money by sending vehicles on Local hauls (short, auto-returning), Line hauls (terminal to terminal, max 400 km) and contract-based Long hauls (500-2,000 km, won by auction). Terminals, demand management, cargo licenses and maintenance are the real strategy levers, and turbos, packs and the Convoy Club VIP subscription are the monetization levers.
- **Why it succeeds:** The game has 10M+ Google Play downloads, a 4.5-star rating from over 100K reviews, and generated DKK 25.2m in revenue in 2025, its first full year of operation, according to Trophy Games' annual report announcement of 10 March 2026. It reuses roughly 80% of a shared codebase and an in-house map server across Trophy Games' "Transport Series," which is the design pattern you should emulate in miniature.
- **For Bangladesh:** Build around the Dhaka-Chattogram N1 corridor, which The Daily Star calls "the main route for around 90 percent of Bangladesh's over $100 billion in international trade." Add Padma and Jamuna bridge tolls, diesel at Tk 135 per litre (under an Energy and Mineral Resources Division order effective 21 September 2026), Tata/Ashok Leyland trucks costing about Tk 28-37 lakh, and disruptions like hartals, monsoon and Eid rush. Use Flutter + Flame + flutter_map with a simple backend, and ship a single-player MVP first.

---

## Key Findings

1. **The core loop is "buy vehicle, assign route, wait in real time, collect, reinvest."** Trucks travel in real time on a world map, and progress continues while you are offline. The official tagline is that you can "drive while being idle on your couch."\[1\]
2. **Demand is the scarce resource, not trucks.** Each route draws on finite daily demand. Line hauls feed local demand: 33% of delivered cargo weight is added to the next day's local demand at that terminal.\[2\] Expansion through terminals is therefore the main growth engine.
3. **Monetization is time and access, not pay-to-win cars.** Sold items include turbos (speedups), coins/tokens, cargo-type licenses through an Add-On Shop, start-up packs from $1.49 to $24.99, special offers up to $54.99, and the Convoy Club subscription ($4.99 weekly or $11.99 monthly on iOS).\[3\]\[4\]
4. **Player complaints point to monetization friction, not the core design.** Reviews flag token walls (one checklist task needing "$13+" or "565-598 advertisement videos"), turbo prices that escalate, expensive licenses, high data and battery use, and not being able to see route demand before buying a vehicle.\[5\]\[6\]\[7\]
5. **The studio's moat is its shared framework and map server.** Trophy Games says its games "share about 80% of the same code base" and use "our map server, a simplified version of Google maps." Truck Manager was "the first title built with our redesigned UI/UX framework."\[8\]
6. **Bangladesh has rich, authentic material for this genre.** It has a single dominant corridor, bridge tolls with clear axle-based tiers, volatile and government-set diesel prices, a culture of overloading, and frequent shocks (unrest, tailbacks, floods). Each of these maps directly onto a game mechanic.

---

## PART 1: Player Strategy Guide

### 1.1 Core gameplay loop

- **Start:** You choose a country and region for your headquarters. The game suggests starting countries, and a to-do list or checklist guides your first actions, with in-game tips for each task.\[9\] The checklists have since expanded from 5 to 15.\[10\]
- **Buy vehicles:** In the garage, use "Order New Vehicle" and filter by delivery country, manufacturer, vehicle type, GVWR and energy source (diesel or electric).\[9\] The game offers nine vehicle types, from panel vans and box vans to rigid trucks, semi-trailer tractors and road trains.\[5\] You can own at most 20 of the same model, and after that the model shows as "Out of Stock" until you sell one.\[11\]
- **Used vehicles:** A Vehicle Auction lets you bid against other players on cheaper used trucks that come with age and mileage. After winning there is a short paperwork time, usually 5-15 minutes, before delivery.\[12\]
- **Create routes:** Tap a vehicle, choose haul type (Local or Line), choose cargo weight class (light or heavy), and either tap "Suggest Route" or build the route manually. An idle vehicle earns nothing.\[9\] The "Assign Route" feature (August 2025) lets you bulk-assign many vehicles to one route.\[13\]
- **Haul types (official rules):**
  - *Local hauls:* short trips to nearby cities that have no terminal. The vehicle returns automatically. Vans need 1 driver to unload, trucks need 2.\[2\]
  - *Line hauls:* terminal to terminal. You must own terminals at both ends, the maximum distance is 400 km, and vehicles do not auto-return, so you re-dispatch them with new cargo. Each delivery consumes only the destination city's demand for that origin.\[2\]
  - *Long hauls:* 500-2,000 km and contract-only. You earn 75% of the contract value on departure and 25% on full completion. Failing a contract brings a fine and you lose the completion bonus. Bidding requires terminals at "Continental" level.\[2\]\[14\]
- **Cargo:** There are six cargo types: Dry, Refrigerated (reefer trucks), Granular (dumpers), Construction (flatbeds), Machinery (heavy only, lowboys) and Hazmat (light only, tankers, "carries risk and higher pay").\[15\] Light cargo loads faster and causes less wear and fuel use. Heavy cargo pays more per delivery but adds wear, fuel use and CO2.\[16\] The four newer types are unlocked with points in the Add-On Shop, and a "price factor" system creates "golden routes" with price boosts.\[17\]
- **Maintenance and MOT:** Vehicles wear down. An overdue MOT can be "caught during operations" and "trigger a costly audit of your entire company."\[18\] Older vehicles bring more wear, breakdowns, accidents, repair costs, insurance penalties and late deliveries.\[19\] Since 2026, incidents also cause a short reputation loss.\[20\] Terminals also suffer wear.
- **Staff and drivers:** Drivers are assigned per vehicle (1 or 2 per unload).\[2\] A Staff page lets you recruit executives with "personalities & perks" that give boosts, and the store text promises "monitor ... staff wages."\[5\]\[21\] I could not retrieve the exact driver-salary table from the help center, so treat any salary or fatigue numbers you see quoted elsewhere as unverified.
- **Fuel and CO2:** The Steam page describes buying "fuel and CO2 quotas at the right time to optimize profits,"\[1\] which is the same commodity-timing mechanic as Airline Manager. Diesel or kWh capacity (storage) is upgraded with tokens.\[5\]
- **Marketing and reputation:** Tap the star or reputation box to run campaigns. Flash Campaign gives an instant boost, Brand Awareness builds over days, Guerilla Initiative has a low chance but big impact, and Green Promotion boosts reputation and electric cargo prices if your CO2 status is green.\[9\]
- **Loans:** I found no credible source confirming a loan system in Truck Manager. Do not assume one exists.

### 1.2 In-game economy

| Element | What it is | How you get it | What it buys |
|---|---|---|---|
| Cash ($) | Main currency | Route revenue, contract payouts, selling vehicles (resale is floored at 5% of purchase price) | Vehicles, terminals, repairs, marketing, fuel |
| Coins / tokens / points | Premium currencies | Purchases, ads, achievements, events (e.g. "Summer Token Event," "Halloween Token Event") | Turbos, capacity upgrades, cargo licenses, checklist tasks |
| Reputation (stars) | Soft multiplier | Marketing, on-time delivery, avoiding incidents | Better prices and demand |
| Goodwill / local presence | Contract score | Completing contracts, steady local and line deliveries | Winning long-haul bids |

**Formulas and ratios that are publicly documented:**
- Long-haul cash flow is 75% on departure and 25% on completion.\[14\]
- Line-haul demand regeneration means 33% of delivered weight is added to the next day's local demand at that terminal.\[2\]
- Long-haul bids are scored on quantity, duration, price, goodwill, company size, local presence and green practices, and "each contractor weighs these factors differently."\[22\]
- The vehicle resale floor is 5% of purchase price.\[23\]

Community "profit per km" formulas for Truck Manager are not well documented in credible sources. One reviewer reported that route income dropped "from around 100K each time I sended my trucks on a route to 34K" after an early boost ended.\[7\] This is consistent with the official "Turbo Start," which makes dispatches "up to 200 times quicker" during the start-up phase.\[4\] **Interpretation:** early-game income is deliberately inflated to hook players, so do not judge your long-term strategy by the first few days.

### 1.3 Progression systems

- **Checklists:** These are guided goal chains (15 as of June 2026) that award rewards and teach systems. Checklist 5 is the known paywall pinch point.\[5\]\[10\]
- **XP by department:** The help center notes that "XP is categorized by department," so different actions level different parts of the company.\[24\]
- **Map expansion:** You buy terminals in new cities and countries. A "Buy Terminal - easy mode" with 3 terminal modes was added for new users in September 2026.\[20\] Terminal level gates long hauls.\[2\]
- **Achievements:** A "Daily Essentials & Achievements" release came on 15 April 2026, and an official "Achievement List" article exists.\[10\]\[25\] I could not verify the exact names you mention ("Not a sprint," "Prodigy") or the count of 56 from a public source, so treat those as your own in-game observation.
- **Research / R&D:** A research system exists (the game sends an "in-game notification when research is complete").\[13\]
- **Multiplayer:** Players compete in long-haul auctions and vehicle auctions and on leaderboards.\[12\]\[22\] A stock exchange feature launched in July 2026 (companies "can invest in each other to grow stock values").\[1\]\[25\] Alliances with "co-op features, seasonal leagues, and shared benefits" were on the May 2026 roadmap as "Near Future."\[26\]

### 1.4 Best strategies (synthesized from official advice and player reports)

**Early game (first days)**
- Follow the official start-up advice: "purchase a terminal near your headquarters to unlock line hauls, and then identify some well-paying local hauls to get the cash flow started."\[27\]
- Match vehicle to job. Panel vans suit light dry cargo on very short routes, box vans suit medium routes with light or heavy cargo, and rigid trucks suit line hauls and heavier loads.\[27\]
- Exploit the Turbo Start window: dispatch as often as possible while dispatches are accelerated.\[4\]
- Do the checklist in order, since it is the fastest XP and reward path.

**Mid game**
- Build terminal pairs within 400 km to unlock line hauls, and use them to regenerate local demand (the 33% rule). This is the most important compounding mechanic.
- Use the Vehicle Auction to expand cheaply, but budget for higher maintenance.\[12\]
- Hunt for "golden routes" with high price factors for each cargo type, rather than simply the longest distance.\[17\]
- Buy fuel and CO2 when prices are low, as in Airline Manager.

**Late game**
- Upgrade terminals to Continental level and bid on long hauls. Never over-commit capacity, because the fine plus the lost 25% completion bonus can erase the profit.\[14\]
- Specialize with licenses (Hazmat pays more but licenses expire, and the game now warns you about Hazmat license expiry).\[20\]
- Keep MOTs current. One overdue truck can trigger a company-wide audit, and incidents now cost reputation.\[18\]\[20\]

**Common beginner mistakes**
- Leaving vehicles idle or "parked" (the game added a resume button for parked vehicles in September 2026).\[20\]
- Buying vehicles before checking whether demand exists. Players complain they "have to buy a vehicle and then create a route" just to see demand.\[5\]
- Expanding to many cities too fast instead of building a dense local network.
- Ignoring MOT and wear on older or auctioned trucks.
- Spending premium currency on turbos whose price escalates. One player saw a 4-hour turbo rise "from about 24 coins" to 46.\[7\]

**Free-to-play vs paying**
- F2P is viable but slow. Use the 15-minute ad turbos (up to 3 per day), the daily gift and token events.\[26\]
- The friction points are token-heavy tasks such as the diesel/kWh capacity checklist task and the cargo licenses (grain, construction, machinery, hazmat).\[5\]\[6\] If you spend at all, the cheapest value is the $1.49 "3x Trucks Start-up Deal" early on.\[4\] Convoy Club only makes sense for committed players, especially since some long-haul contracts are restricted to Convoy Club members.\[22\]

---

## PART 2: Developer / Product Breakdown

### 2.1 Game design analysis

- **Core loop (minutes):** check map, then re-dispatch line-haul vehicles, then collect revenue, then repair and MOT, then buy a vehicle or terminal.
- **Meta loop (days and weeks):** checklists, terminal expansion, licenses, long-haul contracts and goodwill, staff perks, research, stock market, alliances (planned), events.
- **Session design:** Sessions are short check-ins driven by real-time timers, which suits notifications. Revenue arrives when trucks complete trips, local hauls auto-repeat, and line hauls need manual re-dispatch.\[2\] That need for manual action is a deliberate "reason to come back."
- **Real time:** Yes. Trucks move in real time between real cities and can be tracked "live ... via satellite GPS" on the map.\[5\] Turbos compress time.
- **Map:** It is a real-world map served from Trophy Games' own map server ("a simplified version of Google maps"). Cities are real (New York, Tokyo, London and others).\[5\]\[8\]
- **UI structure:** The main screens are a full-screen map with a status side panel (tabs for en-route, completed, parked and pending), a garage or vehicle store with filters, vehicle detail and configuration, Logistics (Local / Line / Long Haul, Active contracts), a reputation and marketing panel, staff, the Add-On Shop, checklists and achievements, and a shop for packs. The help center lists FAQ sections for Achievements, Company Management, Routes, Staff, Cargo, Vehicles & Maintenance and Stock Market.\[28\]
- **Online requirement:** "An online internet-connection is required to play this game."\[5\] All economy state is server-side, which prevents easy save-editing and enables auctions.

### 2.2 Monetization model

| Product (iOS listing) | Price |
|---|---|
| 3x Trucks Start-up Deal | $1.49 |
| Mini Pack | $1.99 |
| Standard Pack | $5.99 |
| Kickstarter Pack | $11.99 |
| Premium Pack | $24.99 |
| Weekly Convoy Club Subscription | $4.99 |
| Monthly Convoy Club Subscription | $11.99 |
| Special Deals / Offers | $0.99 to $54.99 |

- **Ads:** These are rewarded ads (15-minute turbo, up to 3 per day). The current iOS listing says "Contains Advertising," although an older store description claimed the game "is 100% ad free."\[4\]\[26\]\[29\] This is a conflict between store texts. The present reality is opt-in rewarded ads.
- **Convoy Club:** This is a VIP subscription launched in May 2026 ("New VIP option offering awesome benefits throughout the game"). It is also used as a gate for some long-haul contracts,\[22\]\[26\] and a "New Convoy Club Benefit" was announced on 20 October 2026.\[20\] I could not retrieve the full benefit list.
- **Business results:** In February 2025 the game was making DKK 500,000 per month from organic Android users "despite only one-third of planned monetization features being live."\[30\] It set a monthly record of DKK 1.6m in May 2025, and Trophy Games' annual report announcement of 10 March 2026 says that "reaching its first full year of operation, the game generated DKK 25.2m in revenue" (of group revenue of DKK 126.5m). In H1 2026 Trophy Games designated Truck Manager "the primary focus for growth investment."\[31\] For the Transport Series in general, Trophy Games notes that Airline Manager "generates the majority of its revenue within the first three months after user installation," and Truck Manager was explicitly designed to fix weak "mid- and late-game" monetization.\[8\]
- **Lesson for you:** Monetize convenience and specialization (licenses, speed, capacity), not raw power. Avoid escalating prices and token walls inside mandatory tutorials, because that is where the 1-star reviews come from.

### 2.3 Retention mechanics

- A daily gift (previously weekly, changed in June 2026) and Daily Essentials.\[26\]
- Checklists (15), achievements, and XP by department.
- Token events (Summer, Halloween) and a planned Event Center and Daily Missions.\[25\]\[26\]
- Multiplayer: long-haul auctions, vehicle auctions, leaderboards, the stock exchange, and planned alliances with seasonal leagues.
- Notifications for completed research, expiring Hazmat licenses, and trips completing.\[13\]\[20\]
- A shared Discord server across all Transport Series games, plus cross-promotion between them.\[8\]
- Measured retention: Day 1 retention of 25% in Western markets (Airline Manager is 30%), and 40% in Poland and Italy tests.\[30\]

### 2.4 Tech and the studio's shared pattern

- **Publisher structure:** Xombat ApS (Copenhagen) holds the IP and is a 100% subsidiary of Trophy Games Development A/S, which is listed in Copenhagen. Sigurd Andersen created Xombat and Airline Manager.\[8\]
- **Shared framework:** About 80% of the code is shared across the Transport Series (Airline, Shipping, Train, Energy, Truck, Farm Manager). Features built for Truck Manager are "transferred to the other games."\[8\]
- **Map:** An in-house map server, which the studio calls a "moat" because third-party map servers are expensive at scale.\[8\]
- **Platforms:** Android, iOS and Windows (via Google Play PC). A Steam page exists, and a Web/Steam release is on the roadmap.\[1\]\[5\]\[26\]
- **Engine:** No credible public source states the engine. The planned web release and the shared web-style UI framework suggest a web-technology client, but that is an inference, not a confirmed fact.
- **AI use:** The Steam page discloses that "AI in Truck Manager has been used for image creation for some splash arts and characters."\[1\]
- **Data practices:** The Play listing states "Data isn't encrypted" and that location and device IDs may be shared with third parties. One player reported "3GB of data" in a few weeks along with heavy battery use.\[5\] This is a real weakness you can beat.

### 2.5 Reviews and reception

- **Google Play:** 4.5 stars, about 104K-109K reviews, 10M+ downloads, rated 3+.\[5\] Pocket Gamer reports 31.6 million downloads across platforms and over a million pre-registrations at its second anniversary (October 2026).\[32\] On iOS it has 4.8 stars from about 10K ratings.\[4\]
- **Praised:** depth and realism ("helps to teach logistics and management"), a slow but meaningful progression compared with typical idle tycoons, and a clean UI that makes complex decisions "engaging rather than overwhelming."\[4\]\[5\]
- **Complaints (your improvement list):**
  1. Token and pay walls in checklists ("pay-to-play").\[5\]
  2. Escalating premium prices (turbo cost rising).\[7\]
  3. Expensive cargo licenses.\[6\]\[33\]
  4. Income falling sharply once the early boost ends.\[7\]
  5. Not being able to preview route demand before buying a vehicle.\[5\]
  6. Heavy data and battery use.\[5\]
  7. Caps on trucks per model.\[5\]
  8. Requests for trailer swapping and a company logo (from player comments on the help center).\[20\]

### 2.6 Competitors

| Game | Developer | How it differs |
|---|---|---|
| Transit King Tycoon | Bon Games, now owned by Trophy Games | Cartoon, casual; build roads and facilities; seaport; alliances; VIP tiers from $0.99 per week to $17.99 per month |
| Virtual Truck Manager | VDTruck Studio | Closer simulation, EU/US trucks, sells "VTPoints" ($2.99 to $119.99) |
| Truck Star | Century Games | Casual, mass-market tycoon, listed as "Similar" on Play |
| Airline / Shipping / Train / Energy / Farm Manager | Trophy Games | Same framework, different theme. Proof that the formula reskins well |
| Euro Truck Simulator 2 / American Truck Simulator | SCS Software | Driving sims with a light company-management layer. A different audience (PC, hands-on driving) |

**Positioning takeaway:** No major title owns South Asian logistics. A Bangladesh game competes on authenticity and local language, not on scale.

---

## PART 3: Adapting It to Bangladesh

### 3.1 Logistics context worth modelling

**The dominant corridor.** The Dhaka-Chattogram highway (N1) is described as the main route for "around 90 percent of Bangladesh's over $100 billion in international trade." According to Roads and Highways Department data, 35,000-40,000 vehicles use it daily and 35-40% of them carry goods.\[34\] A seminar keynote cited by Bonik Barta found that of the 3.29 million TEUs Chattogram Port handled in FY2024-25, "as much as 96 percent" moved along the Dhaka-Chittagong highway, against 3% by rail and 1% by inland waterway. The Chittagong Port Authority's chairman reported 3,275,627 TEUs handled in calendar 2024, up 7.42% year on year (FICCI rounds this to 3.26 million), and inland container depots normally handle about 3,500 trucks daily.\[35\] **Game implication:** make N1 the "Main Street" of the map. It is the most lucrative route and the most congested.

**Key hubs to place as terminals:** Dhaka (Tejgaon, Gazipur and Savar/Ashulia garment belts), Narayanganj, Chattogram Port and its ICDs, Cumilla, Mongla Port, Benapole land port (the main gateway for India trade), Bogura and Rangpur (northern agriculture), Khulna and Jashore (connected via Padma Bridge), Sylhet, Mymensingh, and the EPZs (Chattogram, Dhaka/Savar, Karnaphuli, Mongla).

**Bridges and tolls (real gazette rates for the Padma Bridge):**

| Vehicle | Padma Bridge toll |
|---|---|
| Pickup | Tk 1,200 |
| Small truck (up to 5 t) | Tk 1,600 |
| Medium truck (5-8 t) | Tk 2,100 |
| Medium truck (8-11 t) | Tk 2,800 |
| Truck (up to 3 axles) | Tk 5,500 |
| Trailer (up to 4 axles) | Tk 6,000 |
| Trailer (each axle above 4) | +Tk 1,500\[36\]\[37\] |

For the Jamuna (Bangabandhu) Bridge, a Bangladesh Bridge Authority notification in force since 19 November 2021 sets Tk 1,000 for a small truck (up from Tk 850), Tk 1,250 for a medium truck (5-8 t), Tk 1,600 for 8-11 t, Tk 2,000 for a 3-axle truck, and Tk 3,000 for a 4-axle trailer plus Tk 1,000 for each extra axle. The Padma tolls were set at about 1.5 times the old ferry fares on the Shimulia-Kathalbari route, which gives you a ready-made "bridge vs ferry" trade-off: the ferry is cheaper but slower and carries weather risk.\[37\]

**Fuel (BDT).** The Energy and Mineral Resources Division raised diesel to Tk 135 per litre, up from Tk 115, effective 21 September 2026. It had already risen by Tk 15 on 18 April 2026. Prices are administered and change by government decree, so a "fuel price shock" event that randomly moves diesel by ±Tk 15-20 is realistic.

**Truck prices (BDT, dealer listings, indicative):**
- Tata LPT 1615 (the workhorse 6-wheel truck, Nitol Motors is the distributor): about Tk 27.75-31.85 lakh for the chassis. The load body costs another Tk 3-3.5 lakh.\[38\]\[39\]\[40\]\[41\]
- Tata LPT 1615/48 TC Gold: Tk 31.6 lakh (May 2024 list).\[42\]
- Tata LPS 4018 prime mover (40 ft trailer): Tk 37.15 lakh.\[43\]
- Tata Prima LX 4928: Tk 45 lakh.\[43\]
- Other common makes to model: Ashok Leyland (Dost pickups and trucks), Eicher, Hino, Isuzu, Mahindra, and covered vans in 9-23 ft sizes.

**Overloading is built into the culture.** Dealers advertise the LPT 1615 with an official payload of 7,000-8,000 kg but a "loading capacity 20-25 ton."\[39\]\[40\] That gap is a perfect risk/reward mechanic: overload for more revenue at the cost of wear, axle-load fines at weighbridges and accident risk.

**Driver pay and informal costs.** The Business Standard reports that companies pay a driver and helper a combined Tk 6,000-7,000 per month plus per-trip pay, so 8 trips a month can earn over Tk 20,000. A 3-day Dhaka-Chattogram round trip pays about Tk 7,000, of which a driver kept "barely Tk 2,500" after food, fuel and checkpoint payments, and drivers described paying "Tk 1,000 and Tk 1,500 at various points" per trip.\[44\] Drivers also describe 16-hour drives and chronic sleep deprivation, which makes a fatigue mechanic authentic.\[44\] Glassdoor's Bangladesh truck-driver figures rest on only 2 salaries and should not be used.\[45\]\[46\]

**Freight rates inside Dhaka (rental market):** covered vans cost about Tk 1,000-3,200 per trip for 9-14 ft and Tk 3,000-6,500 for 16-23 ft. Trucks of 3.5-25 t cost about Tk 2,500-6,000 per trip.\[47\]

**Disruptions to model as events:**
- *Political unrest or hartal:* in a 2024 episode, "No trucks, covered vans, or prime movers [were] operating on the Dhaka-Chattogram highway."\[34\]
- *Congestion:* a 45-km tailback once stranded more than 3,500 vehicles and halted road and rail links with Chattogram.\[35\]
- *Monsoon and flooding* (June-October): slower roads, closed river crossings, higher reefer demand.
- *Eid rush:* demand spikes for garments, livestock and consumer goods, and drivers want leave.
- *Port congestion* at Chattogram, which means detention delays.\[48\]\[49\]

**Cargo types for Bangladesh:** RMG and garment cartons (dry, export, deadline-critical), raw cotton and yarn (inbound from the port), rice and paddy, potatoes and vegetables (northern districts to Dhaka), fish and shrimp (reefer, Khulna/Satkhira to Dhaka and Chattogram), cement and clinker, rod/steel (construction), sand and stone (granular), jute and jute goods, LPG cylinders and fuel (hazmat), and cattle at Eid (a special livestock event).

### 3.2 Localized feature ideas

- **Bangla-first UI** with English toggle, BDT with lakh/crore formatting (e.g. "৳ ৩১,৬০,০০০"), and Bangla numerals as an option.
- **"Highway Police / Weighbridge" checkpoints:** paying "speed money" or taking a delay is a moral-choice mechanic. Keep it satirical and non-instructional.
- **Bridge vs ferry routing** (Padma, Jamuna, Meghna-Gumti) using real toll tiers.
- **Overload slider** with fines, wear and accident probability.
- **Driver + helper (ostad and helper) pairs** with fatigue, salary plus trip bonus, and Eid leave.
- **Seasonal calendar:** Eid-ul-Fitr and Eid-ul-Adha demand spikes, the Boro/Aman harvest, monsoon floods, and winter fog slowing night driving.
- **Garment export deadlines:** missing a shipment cutoff at the port means a contract penalty, which mirrors long-haul contracts.
- **Govt fuel price announcements** as a news ticker event.
- **Local brands as fictionalized lookalikes** ("Tata-like," "Leyland-like") to avoid trademark issues, as Truck Manager does with "models similar to Mercedes, Peterbilt...".\[5\]

### 3.3 Building it in Flutter

- **Rendering:** Use plain Flutter widgets for 90% of screens (lists, garages, finance). Use **Flame** only for animated layers such as trucks moving on the map, or skip Flame entirely and animate markers on the map widget. Tycoon games are UI-heavy, not physics-heavy.
- **Map:** Use **flutter_map** with OpenStreetMap-based tiles. Do not hit the public OSM tile servers at scale, because their usage policy forbids heavy app traffic. Use a commercial tile host with a free tier, or pre-render a stylized Bangladesh map image or vector tiles yourself. Trophy Games' own "map server moat" shows how much map costs matter. Precompute route polylines and distances (using OSRM or GraphHopper offline over OSM data) and ship them as JSON, so the game never needs live routing.
- **Real-time simulation:** Store each trip as `{departAt, arriveAt, routeId, cargo, revenue}` and compute positions on the fly from timestamps. That gives you real-time travel and offline progress cheaply, and it is the same idea as Truck Manager's timers.
- **Backend:**
  - *MVP:* local-only (Hive, Isar or SQLite) and fully offline. This also beats Truck Manager's data and battery complaints.
  - *Phase 2:* **Supabase** (Postgres, row-level security, Edge Functions for server-authoritative payouts) or **Firebase** (Auth, Firestore, Cloud Functions, FCM push). Move money calculations server-side before adding any multiplayer or IAP, to prevent cheating.
- **Monetization (later):** Use rewarded ads (AdMob) for turbos and the `in_app_purchase` package. Price for Bangladesh using local store tiers, and consider bKash-friendly Google Play payment availability.
- **Localization:** Use `flutter_localizations` + `intl` with ARB files for Bangla, and a Bangla font such as Hind Siliguri or Noto Sans Bengali.

### 3.4 Recommendations

1. **Copy the mechanics, not the scale.** The 33% demand-regeneration rule, the 75/25 contract payout, the MOT audit risk and the light/heavy cargo trade-off are elegant, documented and cheap to implement.
2. **Fix the competitor's top complaints from day one:** show route demand before purchase, keep turbo prices fixed, never paywall a tutorial step, and stay offline-friendly with low data use.
3. **Make Bangladesh the feature.** N1 congestion, bridge tolls, overloading, hartal and Eid events, and Bangla UI create a niche no global title fills.
4. **Ship single-player first,** then add leaderboards, then auctions and alliances only if you have retention data.

---

## Caveats

- **Unverified details:** I could not retrieve the exact driver-salary table, the fatigue rules, the Convoy Club benefit list, the engine/tech stack, or the full achievement list (including "Not a sprint" and "Prodigy" and the count of 56) from public sources. No source confirmed a loan system.
- **Third-party sources:** Some strategy points come from the publisher's own help center, which is authoritative on rules but promotional in tone. One "money and gems guide" found in search appears to describe a different or generic game and was not used.
- **Store listing inconsistencies:** Store listings vary by region (the title is "2026" in some and "2027" in others, and review counts range from 104K to 109K). The "ad free" versus "Contains Advertising" texts conflict.
- **Bangladesh prices:** These are volatile. Diesel changed three times in 2026. Truck prices come from dealer classifieds, not official list prices. The Jamuna tolls come from a November 2021 Bridge Authority notification and may have been revised since. Re-verify all of these before release.
- **Company figures:** Trophy Games' revenue and retention numbers are company-reported investor communications, not independently audited per title.

---

## Suggested MVP Feature List: "Truck Manager Bangladesh" (solo Flutter developer, about 3-4 months)

1. **Map:** a stylized Bangladesh map (flutter_map with a custom or vector tile source) with 8-10 cities: Dhaka, Gazipur, Narayanganj, Cumilla, Chattogram Port, Sylhet, Bogura, Rangpur, Khulna, Benapole.
2. **Vehicles:** 4 types (pickup 1.5 t, covered van 7 t, 6-wheel truck such as an LPT 1615 lookalike, prime mover with trailer), with BDT prices in lakh.
3. **Hauls:** Local (auto-return) and Line (terminal to terminal) with real-time trips computed from timestamps and offline progress.
4. **Terminals:** buy terminals in cities, with daily demand per city pair and a line-haul demand boost rule.
5. **Cargo:** 4 types: garments (dry), rice and vegetables (dry or perishable), cement and rod (heavy), fish (reefer, unlockable).
6. **Costs:** diesel at Tk/litre with occasional price-shock events, a driver + helper salary plus trip bonus, Padma and Jamuna tolls by axle class, and wear and repair.
7. **Risk:** an overload slider (more revenue, more wear and fine risk) and a fitness-certificate (MOT-equivalent) timer.
8. **Events:** Eid demand spike, monsoon slowdown, hartal (N1 closed for X hours), and N1 tailback.
9. **Progression:** company level with an XP and checklist of 10-15 tasks, about 20 achievements, and unlocks of new cities and cargo.
10. **UX:** Bangla/English toggle, BDT formatting, push notifications for "trip complete," and a demand preview before buying a vehicle.
11. **Save:** local storage first (Hive or Isar), with optional cloud backup through Firebase or Supabase Auth.
12. **Monetization (post-MVP):** rewarded ads for a 15-minute speed-up and one cosmetic or starter pack at a fixed price. No paywalls in the tutorial.

## Sources

1. [Truck Manager on Steam](https://store.steampowered.com/app/2897710/Truck_Manager/)
2. [What are the differences between each haul type?](https://truckmanager.zendesk.com/hc/en-us/articles/21585472049426-What-are-the-differences-between-each-haul-type)
3. [Truck Manager - 2026 App - App Store](https://apps.apple.com/gm/app/truck-manager-2026/id6474616329)
4. [Truck Manager - 2026 - App Store - Apple](https://apps.apple.com/us/app/truck-manager-2026/id6474616329)
5. [Truck Manager - 2026 - Apps on Google Play](https://play.google.com/store/apps/details?id=com.trophygames.truckmanager)
6. [Truck Manager - 2026 - Apps on Google Play](https://play.google.com/store/apps/details/Truck_Manager_2025?id=com.trophygames.truckmanager&amp%3Bhl=en)
7. [Truck Manager - 2025 - Apps on Google Play](https://play.google.com/store/apps/details?id=com.trophygames.truckmanager&hl=en_CA)
8. <https://trophy-games.com/file/trophy-games-development-as-an-20250311050751.pdf>
9. [Truck Manager - 2025 Beginner Guide - Create a Truck Empire with Tips and Tricks](https://www.ldplayer.net/blog/truck-manager-2025-beginner-guide.html)
10. [New Checklists! Update 10/06/2026](https://truckmanager.zendesk.com/hc/en-us/articles/36298206917778-New-Checklists-Update-10-06-2026)
11. [Why are Trucks 'Out of Stock' in the store?](https://truckmanager.zendesk.com/hc/en-us/articles/37247271767058-Why-are-Trucks-Out-of-Stock-in-the-store)
12. [What is the Vehicle Auction?](https://truckmanager.zendesk.com/hc/en-us/articles/30189363263762-What-is-the-Vehicle-Auction)
13. [New Assign Route Feature! 26/08/2025](https://truckmanager.zendesk.com/hc/en-us/articles/29022376465810-New-Assign-Route-Feature-26-08-2025)
14. [What are long hauls?](https://truckmanager.zendesk.com/hc/en-us/articles/31184276158610-What-are-long-hauls)
15. [Cargo Type Overview](https://truckmanager.zendesk.com/hc/en-us/articles/29863461923218-Cargo-Type-Overview)
16. [What is the difference between light and heavy cargo?](https://truckmanager.zendesk.com/hc/en-us/articles/21585488770962-What-is-the-difference-between-light-and-heavy-cargo)
17. [NEW CARGO TYPES UPDATE! 10/04/2025](https://truckmanager.zendesk.com/hc/en-us/articles/25948197968658-NEW-CARGO-TYPES-UPDATE-10-04-2025)
18. [What does 'MOT' mean?](https://truckmanager.zendesk.com/hc/en-us/articles/21585483112850-What-does-MOT-mean)
19. [Should I replace my old vehicles?](https://truckmanager.zendesk.com/hc/en-us/articles/21585465761042-Should-I-replace-my-old-vehicles)
20. [Patch update for 08/09/2026!](https://truckmanager.zendesk.com/hc/en-us/articles/38747898499474-Patch-update-for-08-09-2026)
21. [Long-haul fixes and improvements! 03/02/2026](https://truckmanager.zendesk.com/hc/en-us/articles/33041126003730-Long-haul-fixes-and-improvements-03-02-2026)
22. [How does long haul bidding work?](https://truckmanager.zendesk.com/hc/en-us/articles/31184455595538-How-does-long-haul-bidding-work)
23. [Bug Fixes for 11/03/2026!](https://truckmanager.zendesk.com/hc/en-us/articles/33947866378130-Bug-Fixes-for-11-03-2026)
24. [User profile for Cathy](https://truckmanager.zendesk.com/hc/en-us/profiles/20205871301266?after=aUgAAAAAAAAAZO5zwGcAAAAAaZKmZV62FgAA&filter_by=articles&sort_by=votes)
25. [Patchnotes](https://truckmanager.zendesk.com/hc/en-us/sections/20732523274898-Patchnotes)
26. [Roadmap Update! 08/05/2026](https://truckmanager.zendesk.com/hc/en-us/articles/35419360696338-Roadmap-Update-08-05-2026)
27. [Start-Up Advice!](https://truckmanager.zendesk.com/hc/en-us/articles/21565329461394-Start-Up-Advice)
28. [General](https://truckmanager.zendesk.com/hc/en-us/sections/20732573193746-General)
29. [Truck Manager - 2026](https://apps.apple.com/app/id6474616329)
30. [Trophy Games Update: Strong Launch for Truck Manager · Trophy Games](https://trophy-games.com/news/trophy-games-update-strong-launch-for-truck-manager)
31. [Trophy Games Delivers 90% Revenue & EBIT Growth in H1 2026](https://www.morningstar.com/news/accesswire/1209262msn/trophy-games-delivers-90-revenue-ebit-growth-in-h1-2026)
32. [Truck Manager marks 2nd anniversary with over 30 million downloads worldwide](https://www.pocketgamer.com/truck-manager-2025/second-anniversary/)
33. [Truck Manager - 2026](https://play.google.com/store/apps/details?id=com.trophygames.truckmanager&hl=en_ZA)
34. [Dhaka-Chattogram highway, the key trade route, faces disruption again](https://www.thedailystar.net/business/news/dhaka-chattogram-highway-the-key-trade-route-faces-disruption-again-3669436)
35. [45-kilometer tailback on Dhaka-Chattogram highway, over 3,500 vehicles stranded](https://www.tbsnews.net/bangladesh/transport/45-kilometer-tailback-dhaka-chattogram-highway-over-3500-vehicles-stranded)
36. [Padma Bridge Toll Rate, Details & Total Cost History 2025](https://bd-info.com/padma-bridge-toll-rate/)
37. [Govt publishes gazette fixing Padma bridge toll](https://www.justnewsbd.com/en/bangladesh/news/16623)
38. [TATA LPT 1615 price in Bangladesh](https://www.clickbd.com/classifieds/ad/1561199-tata-lpt-1615.html)
39. [TATA 1615 GOLD TRUCK 20 FEET](https://www.clickbd.com/bangladesh/2816992-tata-1615-gold-truck-20-feet.html)
40. [TATA LPT 1615 52 EX-2](https://www.clickbd.com/bangladesh/2494603-tata-lpt-1615-52-ex-2.html)
41. [Tata LPT 1615 Gold Price in Bangladesh TruckBangla.com](https://truckbangla.com/tata-lpt-1615-gold/)
42. [tata truck price in bangladesh](https://pickupzone.com.bd/tata-truck/)
43. [Tata Truck Price in BD](https://www.autosbangla.com/tata-truck-bangladesh.html)
44. [The harsh realities of being a trucker in Bangladesh](https://www.tbsnews.net/features/panorama/harsh-realities-being-trucker-bangladesh-1119246)
45. [Salary: Truck Driver in Bangladesh 2025](https://www.glassdoor.com/Salaries/bangladesh-truck-driver-salary-SRCH_IL.0,10_IN27_KO11,23.htm)
46. [Salary: Truck Driver in Dhaka 2026](https://www.glassdoor.com/Salaries/dhaka-truck-driver-salary-SRCH_IL.0,5_IS3812_KO6,18.htm)
47. [Car Rent Price in Bangladesh: Complete Price List & Guide (2026)](https://carrentbd.com/car-rent-price-in-bangladesh/)
48. [Bangladesh’s \$100B Export Dream Has a Logistics Problem, Experts Warn](https://wwd.com/sourcing-journal/logistics/bangladesh-100-billion-export-logistics-overhaul-chattogram-chittagong-port-congestion-vietnam-india-1238949819/)
49. [Bangladesh and India’s Most Active Cargo Ports Strain Under Volume Surge](https://wwd.com/sourcing-journal/logistics/bangladesh-india-chattogram-mundra-port-congestion-cargo-volumes-rail-intermodal-land-ports-containers-1238856438/)
