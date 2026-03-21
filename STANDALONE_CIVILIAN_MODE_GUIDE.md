# Standalone Civilian Mode Guide

This document explains how `cortex_mdt` implements standalone civilian mode today, why it is structured that way, and how to rebuild the same behavior in a new MDT.

## Goal of the mode

Standalone civilian mode gives the MDT a full "fake records" layer that works even when there is no persistent framework-backed citizen/vehicle data available for roleplay.

It is designed for:

- session-only civilian records
- quick random civilian profile generation
- officer-side plate/name lookups that never feel empty
- manual claiming of generated personas by a player
- vehicle registration tied to a generated or claimed civilian

The important design choice is that this is not a separate app. It is a session-scoped in-memory data layer that gets merged into the normal MDT datasets.

## Files that matter

- `shared/config.lua`
  - enables standalone framework/profile behavior
  - defines `Config.standaloneMode`
- `modules/server/permissions.lua`
  - builds a fallback standalone officer profile when framework data is missing
- `modules/server/standalone_mode.lua`
  - the actual standalone civilian/session engine
- `modules/server/store.lua`
  - merges standalone citizens, vehicles, and warrants into normal MDT datasets
- `modules/server/main.lua`
  - exposes RPC endpoints and pushes standalone snapshots to the UI
- `modules/server/unit_state.lua`
  - turns tracked standalone officer players into active MDT units
- `modules/client/nui.lua`
  - forwards NUI callbacks to the standalone RPC endpoints
- `web/src/App.jsx`
  - contains the quick roll, claim, and vehicle registration UI

## How the current mode works

### 1. A standalone-capable profile is always available

`shared/config.lua` sets:

- `Config.framework = 'standalone'`
- `Config.allowStandalone = true`
- `Config.standaloneProfile = { ... }`
- `Config.standaloneMode = { enabled, autoExpiryMinutes, spiciness, neverNoResult, civilianCanSeePublicBolos }`

`modules/server/permissions.lua` uses that to build a fallback MDT profile when Qbox/player data is unavailable. That lets a player still open the MDT and use the standalone tools.

Why this matters:

- your new MDT should not block on a database character record
- standalone mode needs its own permission/profile fallback so the rest of the MDT can still boot

### 2. All standalone data lives in memory for the current server session

`modules/server/standalone_mode.lua` keeps one in-memory state object:

```lua
state = {
    identities = {},
    identityOrder = {},
    identityByName = {},
    vehicles = {},
    vehicleOrder = {},
    bolos = {},
    boloOrder = {},
    players = {},
    counters = { identity = 0, vehicle = 0, note = 0, bolo = 0 },
}
```

This means:

- no SQL writes are required
- records disappear when the resource/session is wiped or when they expire
- records can still feel persistent during the active RP session

### 3. Each connected player gets a session record

The real "session-tied player" logic is `ensurePlayer(source)`.

Each source gets:

```lua
{
    role = '',
    identities = {},
    plates = {},
    lastIdentityId = nil,
}
```

That player record is the link between the live FiveM source and the session-only standalone data.

What it tracks:

- current MDT role: `officer` or `civilian`
- which standalone identities this player owns/claimed
- which standalone plates this player registered
- the last identity they touched, so vehicle registration can default to it

On player drop, `handlePlayerDropped(source)` removes the session player record.

### 4. Role controls behavior, not just UI

`StandaloneMode.getRole()` and `StandaloneMode.setRole()` store the role on the session player record.

`modules/server/main.lua` exposes `cortex_mdt:server:standaloneSetRole`, which:

- validates `officer` vs `civilian`
- updates standalone role
- optionally syncs ERS shift state
- updates unit state atomically
- pushes a fresh `standalone:state` payload to the UI

This is important because standalone civilian mode is permission-driven:

- officers can search/generate broader data, flag vehicles, verify identities, create BOLOs
- civilians mostly work inside their own claimed records

## Identity generation logic

There are two generation paths.

### A. Explicit "roll identity"

The UI sends `cortex:standaloneUpsertIdentity` with `roll = true`.

Server flow:

1. `StandaloneMode.upsertIdentity(...)`
2. no existing identity found
3. build a random full name from `FIRST_NAMES` + `LAST_NAMES`
4. call `createIdentity(name, source, true)`

The random full name is seeded from:

```lua
('%s:%s:%s'):format(source, GetGameTimer(), state.counters.identity)
```

That gives enough variation for repeated rolls in one session.

### B. Search-generated fallback records

If an officer searches a name and no result exists, `StandaloneMode.searchCitizens()` can auto-create one when `neverNoResult = true`.

That flow:

1. officer searches name
2. no citizen rows match
3. `createIdentity(query, nil, true)` creates a generated record from the searched name

This is what makes traffic stop RP feel fast: the officer never gets an empty result screen.

## Why generated identities feel consistent

`createIdentity()` hashes the normalized name and derives the profile from that hash.

The name hash drives:

- DOB
- address
- phone
- occupation
- gender
- risk tier
- flags
- license status
- prior charges
- "history hooks"

So the same normalized name will resolve to the same generated persona within the session.

That is the core logic behind believable standalone RP:

- the profile feels authored
- it is cheap to generate
- it is deterministic enough to be reused consistently

## Risk tiers and "spiciness"

The generator uses `tierFromHash(h)`.

Possible tiers:

- `clean`
- `suspicious`
- `hot`

`Config.standaloneMode.spiciness` changes the probability thresholds:

- `realistic` produces fewer hot/suspicious hits
- `arcade` produces more

That tier then affects the generated profile:

- suspicious: flight risk, watch status, suspended license, light prior traffic history
- hot: warrant, violent, danger status, revoked license, serious priors

If you rebuild this in a new MDT, keep this as a separate function. It should be easy to tune without rewriting your generators.

## Claimed vs generated profiles

Every standalone identity has these important flags:

- `generated`
- `claimed`
- `ownerSource`
- `published`
- `verified`
- `locked`
- `pinned`
- `expiresAtUnix`

Meaning:

- `generated = true`: machine-created filler record
- `claimed = true`: a player has adopted it as their RP persona
- `ownerSource`: current session owner
- `verified + locked`: officers finalized it; civilians should stop mutating it
- `pinned`: exempt from normal auto cleanup

Claiming happens through `StandaloneMode.claimIdentity()`:

- find by `identityId` or name
- set `claimed = true`
- set `generated = false`
- set `ownerSource = source`
- add it to `player.identities`
- set `player.lastIdentityId`

This is how you turn a quick generated NPC-style record into a player-owned civilian persona.

## Vehicle generation and registration logic

### Vehicle generation

`createVehicle(plate, ownerId, ownerSource, generated)` hashes the normalized plate and derives:

- default model
- default color
- status
- risk
- strikes
- registration status
- insurance status
- flags
- risk tier

Exactly like identities, generated plates feel stable because the plate hash drives the result.

### Vehicle registration

`StandaloneMode.registerCurrentVehicle()` is the actual registration flow.

Inputs it accepts:

- `identityId`
- `ownerIdentityId`
- `citizenId`
- `useLastIdentity`
- `plate`
- `vehiclePlate`
- `dispatchPlate`
- `model`
- `vehicleModel`
- `color`

Behavior:

1. resolve the owner identity
2. if `useLastIdentity = true`, use `player.lastIdentityId`
3. if no plate was passed, pull the current in-game vehicle plate from the player's ped
4. create or reuse the standalone vehicle row
5. set:
   - `ownerId = owner.id`
   - `owner = owner.name`
   - `ownerSource = source`
6. store the plate in `player.plates`

This is the key part you asked for: vehicles are registered individually, and ownership is tied to the generated or claimed standalone player record through `ownerId`.

## How player-to-vehicle linking is maintained

The link is simple and should stay simple in your new MDT.

Identity side:

- `player.identities[row.id] = true`
- `player.lastIdentityId = row.id`

Vehicle side:

- `row.ownerId = identity.id`
- `row.owner = identity.name`
- `player.plates[row.plate] = true`

When an identity name changes in `upsertIdentity()`, the code loops vehicles and refreshes `vehicle.owner` for matching `ownerId`.

When an identity is deleted, matching vehicles are detached:

- `ownerId = nil`
- `owner = 'Unassigned'`

That is the correct design. Vehicles should reference the identity by stable id, not by name.

## Expiry and cleanup logic

Standalone mode is session-scoped, but it still self-cleans.

`purgeExpired()` removes unpinned:

- identities
- vehicles
- BOLOs

based on `expiresAtUnix`.

The expiry time is refreshed whenever a record is updated, unless it is pinned.

There are also manual cleanup actions:

- `wipeSession`
- `cleanupUnpinnedGenerated`
- `deleteScene`

If you reimplement this, keep both:

- automatic expiry for noise reduction
- manual cleanup for admins or scene reset workflows

## How standalone data appears inside the MDT

This is an important architectural point.

The standalone data is not rendered in a separate silo. `modules/server/store.lua` merges standalone rows into the normal datasets:

- `extendCitizenDataset(...)`
- `extendVehicleDataset(...)`
- `extendWarrantDataset(...)`

It also uses standalone profile lookups in `buildCitizenProfile(...)`.

That means your new MDT should do the same thing:

- keep your main citizens/vehicles screens
- inject standalone rows into the normal result sets
- mark them with `standalone = true`

That avoids building a second MDT just for standalone RP.

## Current API surface

If you want feature parity, your new MDT should expose the same kind of service methods or RPCs:

- `standaloneState`
- `standaloneSetRole`
- `standaloneUpsertIdentity`
- `standaloneClaimIdentity`
- `standaloneVerifyIdentity`
- `standalonePublishIdentity`
- `standaloneRegisterVehicle`
- `standaloneSetVehicleFlag`
- `standaloneUpdateVehicleFields`
- `standaloneAddQuickNote`
- `standaloneCreateBolo`
- `standaloneClearBolo`
- `standaloneDeleteRecord`
- `standaloneSetPinned`
- `standaloneCleanup`
- `standaloneSetSpiciness`

Even if your new MDT uses a different transport, keep the service boundaries similar.

## Recommended re-implementation for a new MDT

### 1. Build a dedicated standalone session service

Do not scatter this logic across UI callbacks.

Create one server service/module, for example:

```lua
StandaloneSessionService = {
    players = {},
    identities = {},
    vehicles = {},
    bolos = {},
    config = {},
}
```

That service should own:

- role state
- generators
- ownership
- permissions
- cleanup
- lookup/merge helpers

### 2. Use stable ids and separate indexes

Recommended indexes:

```lua
playersBySource[source]
identitiesById[id]
identityIdByNormalizedName[name]
vehiclesByPlate[plate]
```

Do not use display names as your primary key.

### 3. Keep generation deterministic after the initial roll

Use two layers:

- random roll source to create a full name
- deterministic hash of normalized name/plate to fill the rest of the record

That gives:

- variety on creation
- consistency after creation

### 4. Tie everything to the live FiveM source for the session

Your player session object should at minimum be:

```lua
{
    source = source,
    role = 'civilian',
    identityIds = {},
    vehiclePlates = {},
    lastIdentityId = nil,
}
```

This is enough to support:

- ownership checks
- "register to last identity"
- player-scoped management UI

### 5. Register vehicles against identity id, not player source

Correct relationship:

```lua
vehicle.ownerIdentityId = identity.id
vehicle.ownerSource = source
```

Why:

- a player may own multiple personas in one session
- the identity is the RP owner
- the source is only the live session controller

### 6. Merge standalone rows into the normal MDT datasets

Do not build separate citizens and vehicles pages if you can avoid it.

Instead:

1. fetch persistent rows
2. fetch standalone rows
3. merge by `citizenId` or `plate`
4. mark standalone rows with `standalone = true`

This is the cleanest way to keep UX simple.

## Suggested minimal data contracts

### Standalone identity

```lua
{
    id = 'stn_p_000001',
    name = 'Alex Hill',
    firstName = 'Alex',
    lastName = 'Hill',
    dob = '1994-05-12',
    address = '142 Alta St',
    phone = '555-555-1212',
    occupation = 'Courier',
    gender = 'Male',
    nationality = 'US',
    status = 'WATCH',
    licenseStatus = 'Suspended',
    licenses = {},
    flags = {},
    previousCharges = {},
    historyHooks = {},
    generated = true,
    claimed = false,
    ownerSource = nil,
    published = true,
    verified = false,
    locked = false,
    pinned = false,
    createdAt = '...',
    updatedAt = '...',
    expiresAtUnix = 0,
}
```

### Standalone vehicle

```lua
{
    id = 'stn_v_000001',
    plate = '8ABC123',
    model = 'Tailgater',
    color = 'Black',
    ownerId = 'stn_p_000001',
    owner = 'Alex Hill',
    ownerSource = 12,
    status = 'Watch',
    risk = 'Medium',
    strikes = 1,
    registrationStatus = 'Expired',
    insuranceStatus = 'Lapsed',
    flags = {},
    generated = false,
    published = true,
    verified = false,
    locked = false,
    pinned = false,
    createdAt = '...',
    updatedAt = '...',
    expiresAtUnix = 0,
}
```

## Recommended flow for your new MDT

### Civilian quick-roll flow

1. Player switches MDT mode to `civilian`.
2. Player clicks `Roll Identity`.
3. Server creates a random full name.
4. Server derives the rest of the record from the name hash.
5. Record is marked claimed by that player's source.
6. UI refreshes standalone state and citizen results.

### Officer lookup flow

1. Officer searches a name or plate.
2. If no persistent result exists and standalone generation is enabled:
3. Server auto-generates a standalone identity or vehicle.
4. Result is returned as a normal MDT row with `standalone = true`.

### Vehicle registration flow

1. Civilian chooses a claimed/generated identity.
2. UI sends `identityId` plus optional plate/model/color.
3. Server resolves current vehicle plate if one was not entered.
4. Server creates or updates a standalone vehicle record.
5. Vehicle is linked to `ownerId = identity.id`.
6. Citizen profile now shows that vehicle.

## Pseudocode blueprint

```lua
function rollStandaloneIdentity(source, payload)
    local player = ensureSessionPlayer(source)
    local fullName = payload.name

    if payload.roll == true or fullName == '' then
        fullName = randomFirstName() .. ' ' .. randomLastName()
    end

    local identity = buildIdentityFromName(fullName)
    identity.generated = payload.roll == true
    identity.claimed = true
    identity.ownerSource = source

    identitiesById[identity.id] = identity
    identityIdByNormalizedName[normalizeName(identity.name)] = identity.id

    player.identityIds[identity.id] = true
    player.lastIdentityId = identity.id

    return identity
end

function registerStandaloneVehicle(source, payload)
    local player = ensureSessionPlayer(source)
    local identityId = payload.identityId or player.lastIdentityId
    local identity = identitiesById[identityId]
    if not identity then return nil, 'owner not found' end

    local plate = normalizePlate(payload.plate)
    if plate == '' then
        plate = resolveCurrentVehiclePlate(source)
    end

    local vehicle = vehiclesByPlate[plate] or buildVehicleFromPlate(plate)
    vehicle.ownerId = identity.id
    vehicle.owner = identity.name
    vehicle.ownerSource = source
    vehicle.generated = false

    vehiclesByPlate[plate] = vehicle
    player.vehiclePlates[plate] = true

    return vehicle
end
```

## What I would keep exactly in a rewrite

- session player map keyed by FiveM source
- identity ids as the true owner key
- plate-hash and name-hash deterministic generation
- auto-expiry with pinning
- search fallback that auto-generates when no result exists
- merge standalone rows into the main MDT datasets

## What I would simplify in a rewrite

- keep standalone logic in one service file plus one API file
- define explicit DTOs for identity and vehicle rows
- make permissions clearer: officer, civilian owner, admin
- isolate generator tuning into config tables
- add a single serializer for UI payloads instead of shaping rows in multiple places

## Suggested implementation order for your new MDT

1. Build the standalone session store.
2. Add player role switching and `standaloneState`.
3. Add identity generation and claim flow.
4. Add vehicle registration tied to `ownerId`.
5. Add citizen profile view that resolves linked vehicles.
6. Merge standalone rows into normal citizen/vehicle search.
7. Add expiry, pinning, and cleanup tools.
8. Add optional officer-only extras like BOLOs, flags, and verification.

## Bottom line

The current standalone civilian mode is basically a session-only identity/vehicle registry layered on top of the MDT. The core pattern to carry into your new MDT is:

- track each live player by source
- let them own one or more standalone civilian identities
- generate believable profile data from stable hashes
- register vehicles one at a time against identity ids
- merge those rows into the normal MDT experience instead of making a second system

If you keep that structure, you can rebuild the feature cleanly in any new MDT without depending on Qbox character data or permanent SQL-backed civilian records.
