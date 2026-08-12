local state = {
    citizens = {},
    citizenOrder = {},
    sessions = {},
    counter = 0,
    vehicles = {},
    vehicleOrder = {},
    vehicleByPlate = {},
    vehicleCounter = 0,
}

local FIRST_NAMES = {
    'Alex', 'Avery', 'Bailey', 'Cameron', 'Casey', 'Devon', 'Drew', 'Emerson',
    'Harper', 'Hayden', 'Jamie', 'Jordan', 'Kai', 'Logan', 'Morgan', 'Parker',
    'Quinn', 'Reese', 'Rowan', 'Sawyer', 'Skyler', 'Taylor',
}

local LAST_NAMES = {
    'Allen', 'Bennett', 'Brooks', 'Carter', 'Collins', 'Diaz', 'Foster', 'Garcia',
    'Harper', 'Hill', 'Jordan', 'Kelly', 'Lopez', 'Marshall', 'Miller', 'Perry',
    'Reed', 'Rivera', 'Sanchez', 'Turner', 'Walker', 'Young',
}

local STREETS = {
    'Alta St', 'Bay City Ave', 'Del Perro Blvd', 'Dutch London St', 'Elgin Ave',
    'Forum Dr', 'Grove St', 'Hawick Ave', 'Innocence Blvd', 'Jamestown St',
    'Mirror Park Blvd', 'Palomino Ave', 'Power St', 'Popular St', 'Strawberry Ave',
}

local OCCUPATIONS = {
    'Courier', 'Mechanic', 'Bartender', 'Rideshare Driver', 'Project Manager',
    'Security Contractor', 'Freelance Designer', 'Retail Lead', 'Account Executive',
    'Dock Worker', 'Dispatcher', 'Office Administrator',
}

local NATIONALITIES = {
    'San Andreas', 'United States', 'Canadian', 'British', 'Mexican', 'Australian',
}

local EYE_COLORS = { 'Brown', 'Blue', 'Green', 'Hazel', 'Gray' }
local BLOOD_TYPES = { 'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-' }
local GENDERS = { 'Male', 'Female', 'Non-binary' }

local VEHICLE_MODELS = {
    'Bravado Buffalo', 'Vapid Dominator', 'Karin Sultan RS', 'Canis Seminole',
    'Declasse Granger', 'Ubermacht Oracle', 'Albany Cavalcade', 'Annis Elegy Retro',
    'Obey Tailgater S', 'Benefactor Schafter', 'Pfister Comet S2', 'Dinka Blista Kanjo',
}

local VEHICLE_COLORS = {
    'Matte Black', 'Midnight Blue', 'Pearl White', 'Graphite Gray',
    'Racing Red', 'Silver', 'Forest Green', 'Sandstone',
}

local VEHICLE_CLASSES = {
    'Compacts', 'Sedans', 'SUVs', 'Coupes', 'Muscle', 'Sports',
    'Sports Classics', 'Motorcycles', 'Off-Road', 'Vans', 'Super',
}

local VEHICLE_CLASS_LABELS = {
    [0] = 'Compacts',
    [1] = 'Sedans',
    [2] = 'SUVs',
    [3] = 'Coupes',
    [4] = 'Muscle',
    [5] = 'Sports Classics',
    [6] = 'Sports',
    [7] = 'Super',
    [8] = 'Motorcycles',
    [9] = 'Off-Road',
    [10] = 'Industrial',
    [11] = 'Utility',
    [12] = 'Vans',
    [13] = 'Cycles',
    [14] = 'Boats',
    [15] = 'Helicopters',
    [16] = 'Planes',
    [17] = 'Service',
    [18] = 'Emergency',
    [19] = 'Military',
    [20] = 'Commercial',
    [21] = 'Trains',
    [22] = 'Open Wheel',
}

local VALID_REGISTRATION_STATUSES = {
    valid = true,
    expired = true,
    suspended = true,
    stolen = true,
    unregistered = true,
}

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$') or ''
end

local function defaultMugshotUrl()
    return trim(Config and Config.DefaultMugshot or '')
end

local function titleCase(value)
    local input = trim(value)

    if input == '' then
        return ''
    end

    return input:gsub('(%a)([%w\']*)', function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local function splitName(fullName)
    local name = trim(fullName)

    if name == '' then
        return '', ''
    end

    local firstName, lastName = name:match('^(%S+)%s+(.+)$')

    if firstName and lastName then
        return titleCase(firstName), titleCase(lastName)
    end

    return titleCase(name), 'Citizen'
end

local function normalizeName(fullName)
    return trim(fullName):lower():gsub('%s+', ' ')
end

local function normalizePlate(value)
    return trim(value):upper():gsub('%s+', ' ')
end

local function hashValue(text)
    local hash = 5381

    for i = 1, #text do
        hash = ((hash * 33) + text:byte(i)) % 2147483647
    end

    return hash
end

local function pickFrom(list, seed, offset)
    local size = #list

    if size == 0 then
        return ''
    end

    return list[((seed + (offset or 0)) % size) + 1]
end

local function normalizeFlagList(flags)
    local results = {}
    local seen = {}

    if type(flags) ~= 'table' then
        return results
    end

    if #flags > 0 then
        for i = 1, #flags do
            local flag = trim(flags[i])
            if flag ~= '' and not seen[flag] then
                seen[flag] = true
                results[#results + 1] = flag
            end
        end
    else
        for key, value in pairs(flags) do
            if value then
                local flag = trim(key)
                if flag ~= '' and not seen[flag] then
                    seen[flag] = true
                    results[#results + 1] = flag
                end
            end
        end
    end

    table.sort(results)

    return results
end

local function hasFlag(flags, expected)
    local target = trim(expected)

    if target == '' then
        return false
    end

    local normalized = normalizeFlagList(flags)

    for i = 1, #normalized do
        if normalized[i] == target then
            return true
        end
    end

    return false
end

local function getConfig()
    return type(Config.StandaloneCivilianMode) == 'table' and Config.StandaloneCivilianMode or {}
end

local function getCitizenPrefix()
    local prefix = trim(getConfig().citizenPrefix)
    return prefix ~= '' and prefix:upper() or 'STN'
end

local function ensureSession(source)
    if not state.sessions[source] then
        state.sessions[source] = {
            citizenIds = {},
            activeCitizenId = nil,
            lastGeneratedCitizenId = nil,
            vehicleIds = {},
        }
    end

    return state.sessions[source]
end

local function formatCitizenId(index)
    return ('%s-%04d'):format(getCitizenPrefix(), index)
end

local function formatVehicleId(index)
    return ('%sV-%04d'):format(getCitizenPrefix(), index)
end

local function formatPhone(seed)
    local part1 = (seed % 900) + 100
    local part2 = (math.floor(seed / 10) % 9000) + 1000
    return ('555-%03d-%04d'):format(part1, part2)
end

local function formatDateOfBirth(seed)
    local year = 1972 + (seed % 28)
    local month = (math.floor(seed / 13) % 12) + 1
    local day = (math.floor(seed / 97) % 28) + 1
    return ('%04d-%02d-%02d'):format(year, month, day)
end

local function formatHeight(seed)
    local feet = 5 + (seed % 2)
    local inches = 2 + (math.floor(seed / 11) % 11)
    return ("%d'%02d\""):format(feet, inches)
end

local function formatExpiry(seed)
    local year = 2026 + (seed % 3)
    local month = (math.floor(seed / 7) % 12) + 1
    local day = (math.floor(seed / 23) % 28) + 1
    return ('%04d-%02d-%02d'):format(year, month, day)
end

local function buildFingerprint(citizenId, seed)
    return ('%s-%06d'):format(citizenId:gsub('%W', ''), seed % 1000000)
end

local function buildEmergencyContact(firstName, seed)
    local emergencyFirst = pickFrom(FIRST_NAMES, seed, 4)
    local emergencyLast = pickFrom(LAST_NAMES, seed, 7)
    return ('%s %s (%s)'):format(emergencyFirst, emergencyLast, formatPhone(seed + #firstName))
end

local function buildAddress(seed)
    local streetNumber = 100 + (seed % 8900)
    return ('%d %s, Los Santos'):format(streetNumber, pickFrom(STREETS, seed, 2))
end

local function buildVin(seed)
    local alphabet = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'
    local vin = {}

    for i = 1, 17 do
        local index = ((seed + (i * 37)) % #alphabet) + 1
        vin[i] = alphabet:sub(index, index)
    end

    return table.concat(vin)
end

local function normalizeRegistrationStatus(value)
    local status = trim(value):lower()

    if status == 'registered' then
        status = 'valid'
    end

    if VALID_REGISTRATION_STATUSES[status] then
        return status
    end

    return 'valid'
end

local function normalizeVehicleClass(value, seed)
    local raw = trim(value)

    if raw ~= '' then
        local numeric = tonumber(raw)
        if numeric and VEHICLE_CLASS_LABELS[numeric] then
            return VEHICLE_CLASS_LABELS[numeric]
        end

        return raw
    end

    return pickFrom(VEHICLE_CLASSES, seed, 5)
end

local function buildCitizenRecord(source, fullName)
    local firstName, lastName = splitName(fullName)
    local normalized = normalizeName(('%s %s'):format(firstName, lastName))
    local seed = hashValue(('%s:%s:%s'):format(source, normalized, state.counter))
    local citizenId = formatCitizenId(state.counter)
    local createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

    return {
        id = citizenId,
        citizen_id = citizenId,
        first_name = firstName,
        last_name = lastName,
        dob = formatDateOfBirth(seed),
        gender = pickFrom(GENDERS, seed, 5),
        phone = formatPhone(seed),
        mugshot = defaultMugshotUrl(),
        fingerprint = buildFingerprint(citizenId, seed),
        flags = {},
        notes = nil,
        email = ('%s.%s@%s'):format(
            firstName:lower(),
            lastName:lower(),
            pickFrom({ 'lsmail.com', 'citylink.sa', 'mailbox.local' }, seed, 8)
        ),
        address = buildAddress(seed),
        nationality = pickFrom(NATIONALITIES, seed, 3),
        occupation = pickFrom(OCCUPATIONS, seed, 6),
        height = formatHeight(seed),
        eye_color = pickFrom(EYE_COLORS, seed, 9),
        blood_type = pickFrom(BLOOD_TYPES, seed, 11),
        emergency_contact = buildEmergencyContact(firstName, seed),
        standalone = true,
        generated = true,
        claimed = false,
        ownerSource = nil,
        createdBySource = source,
        createdAt = createdAt,
        updatedAt = createdAt,
    }
end

local function getCitizenDisplayName(citizen)
    if not citizen then
        return 'Unassigned'
    end

    return (('%s %s'):format(citizen.first_name or '', citizen.last_name or ''):gsub('%s+', ' '):match('^%s*(.-)%s*$') or '')
end

local function listVehicleRowsForCitizen(citizenId)
    local rows = {}

    if trim(citizenId) == '' then
        return rows
    end

    for i = 1, #state.vehicleOrder do
        local vehicle = state.vehicles[state.vehicleOrder[i]]
        if vehicle and vehicle.owner_citizen_id == citizenId then
            rows[#rows + 1] = vehicle
        end
    end

    return rows
end

local function countVehiclesForCitizen(citizenId)
    return #listVehicleRowsForCitizen(citizenId)
end

local function serializeVehicle(vehicle, source)
    if not vehicle then
        return nil
    end

    local owner = vehicle.owner_citizen_id and state.citizens[vehicle.owner_citizen_id] or nil
    local ownerName = owner and getCitizenDisplayName(owner) or (vehicle.owner_citizen_id and 'Unknown Owner' or 'Unassigned')

    return {
        id = vehicle.id,
        vehicleId = vehicle.vehicle_id,
        vehicle_id = vehicle.vehicle_id,
        plate = vehicle.plate,
        vin = vehicle.vin,
        ownerCitizenId = vehicle.owner_citizen_id,
        owner_citizen_id = vehicle.owner_citizen_id,
        ownerName = ownerName,
        owner_name = ownerName,
        ownerFirst = owner and owner.first_name or nil,
        owner_first = owner and owner.first_name or nil,
        ownerLast = owner and owner.last_name or nil,
        owner_last = owner and owner.last_name or nil,
        owner_cid = vehicle.owner_citizen_id,
        model = vehicle.model,
        color = vehicle.color,
        vehicleClass = vehicle.vehicle_class,
        vehicle_class = vehicle.vehicle_class,
        registrationStatus = vehicle.registration_status,
        registration_status = vehicle.registration_status,
        insurance = vehicle.insurance_status,
        insurance_status = vehicle.insurance_status,
        regExpiry = vehicle.reg_expiry,
        reg_expiry = vehicle.reg_expiry,
        year = vehicle.year,
        flags = normalizeFlagList(vehicle.flags),
        notes = vehicle.notes,
        standalone = true,
        isOwner = vehicle.ownerSource == source,
        createdAt = vehicle.createdAt,
        updatedAt = vehicle.updatedAt,
    }
end

local function serializeCitizen(citizen, source)
    if not citizen then
        return nil
    end

    local session = ensureSession(source)
    local fullName = getCitizenDisplayName(citizen)
    local warrantCount = hasFlag(citizen.flags, 'wanted') and 1 or 0
    local citationCount = hasFlag(citizen.flags, 'speeding_prior') and 1 or 0
    local recordCount = trim(citizen.notes) ~= '' and 1 or 0

    return {
        id = citizen.id,
        citizenId = citizen.citizen_id,
        citizen_id = citizen.citizen_id,
        firstName = citizen.first_name,
        first_name = citizen.first_name,
        lastName = citizen.last_name,
        last_name = citizen.last_name,
        fullName = fullName,
        dob = citizen.dob,
        dateOfBirth = citizen.dob,
        gender = citizen.gender,
        phone = citizen.phone,
        mugshot = trim(citizen.mugshot) ~= '' and citizen.mugshot or defaultMugshotUrl(),
        fingerprint = citizen.fingerprint,
        flags = normalizeFlagList(citizen.flags),
        notes = citizen.notes,
        email = citizen.email,
        address = citizen.address,
        nationality = citizen.nationality,
        occupation = citizen.occupation,
        height = citizen.height,
        eyeColor = citizen.eye_color,
        eye_color = citizen.eye_color,
        bloodType = citizen.blood_type,
        blood_type = citizen.blood_type,
        emergencyContact = citizen.emergency_contact,
        emergency_contact = citizen.emergency_contact,
        vehicleCount = countVehiclesForCitizen(citizen.citizen_id),
        citationCount = citationCount,
        warrantCount = warrantCount,
        recordCount = recordCount,
        standalone = true,
        generated = citizen.generated == true,
        claimed = citizen.claimed == true,
        isOwner = citizen.ownerSource == source,
        isActive = session.activeCitizenId == citizen.citizen_id,
        createdAt = citizen.createdAt,
        updatedAt = citizen.updatedAt,
    }
end

local function setCitizenActive(source, citizenId)
    local session = ensureSession(source)
    session.activeCitizenId = citizenId
end

local function getActiveCitizen(source)
    local session = ensureSession(source)

    if session.activeCitizenId and state.citizens[session.activeCitizenId] then
        local active = state.citizens[session.activeCitizenId]
        if active.ownerSource == source then
            return active
        end
    end

    for i = 1, #state.citizenOrder do
        local citizenId = state.citizenOrder[i]
        local citizen = state.citizens[citizenId]

        if citizen and citizen.ownerSource == source then
            session.activeCitizenId = citizenId
            return citizen
        end
    end

    session.activeCitizenId = nil

    return nil
end

local function getVisibleCitizenIds(source)
    local session = ensureSession(source)
    local ids = {}

    for i = 1, #state.citizenOrder do
        local citizenId = state.citizenOrder[i]
        local citizen = state.citizens[citizenId]

        if citizen and session.citizenIds[citizenId] then
            ids[#ids + 1] = citizenId
        end
    end

    return ids
end

local function listOwnedCitizens(source)
    local results = {}
    local ids = getVisibleCitizenIds(source)

    for i = 1, #ids do
        local citizen = state.citizens[ids[i]]
        if citizen then
            results[#results + 1] = serializeCitizen(citizen, source)
        end
    end

    return results
end

local function listAvailableCitizens(source)
    return listOwnedCitizens(source)
end

local function listVehiclesForCitizen(citizenId, source)
    local rows = listVehicleRowsForCitizen(citizenId)
    local vehicles = {}

    for i = 1, #rows do
        vehicles[#vehicles + 1] = serializeVehicle(rows[i], source)
    end

    return vehicles
end

local function getCurrentVehicles(source)
    local activeCitizen = getActiveCitizen(source)

    if not activeCitizen then
        return {}
    end

    return listVehiclesForCitizen(activeCitizen.citizen_id, source)
end

local function getCivilianProfile(source)
    local citizen = getActiveCitizen(source)

    if citizen then
        return serializeCitizen(citizen, source)
    end

    local playerName = GetPlayerName(source) or ('Citizen %s'):format(source)
    local firstName, lastName = splitName(playerName)

    return {
        firstName = firstName ~= '' and firstName or 'Citizen',
        lastName = lastName ~= '' and lastName or tostring(source),
        citizenId = nil,
        citizen_id = nil,
        vehicleCount = 0,
        citationCount = 0,
        warrantCount = 0,
        recordCount = 0,
        standalone = true,
        generated = false,
        claimed = false,
        hasActiveCitizen = false,
    }
end

local function buildStatePayload(source)
    local session = ensureSession(source)
    local config = getConfig()
    local citizens = listOwnedCitizens(source)
    local activeCitizen = getActiveCitizen(source)

    return {
        citizens = citizens,
        vehicles = activeCitizen and listVehiclesForCitizen(activeCitizen.citizen_id, source) or {},
        activeCitizenId = session.activeCitizenId,
        civilian = serializeCitizen(activeCitizen, source) or getCivilianProfile(source),
        standaloneEnabled = true,
        maxCitizensPerSession = tonumber(config.maxCitizensPerSession) or 8,
    }
end

local function getState(source)
    return buildStatePayload(source)
end

local function setExclusiveClaim(source, citizenId)
    local citizen = state.citizens[trim(citizenId)]

    if not citizen then
        return nil, 'Citizen not found.'
    end

    if citizen.ownerSource and citizen.ownerSource ~= source then
        return nil, 'Citizen is already claimed by another session.'
    end

    local session = ensureSession(source)
    if not session.citizenIds[citizen.citizen_id] and citizen.createdBySource ~= source then
        return nil, 'You can only claim civilians from your own session.'
    end

    local updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

    for id, row in pairs(state.citizens) do
        if row.ownerSource == source and id ~= citizen.citizen_id then
            row.ownerSource = nil
            row.claimed = false
            row.updatedAt = updatedAt
        end
    end

    session.citizenIds[citizen.citizen_id] = true
    citizen.ownerSource = source
    citizen.claimed = true
    citizen.updatedAt = updatedAt
    setCitizenActive(source, citizen.citizen_id)

    return serializeCitizen(citizen, source)
end

local function buildVehicleRecord(source, payload, ownerCitizenId)
    payload = type(payload) == 'table' and payload or {}

    local plate = normalizePlate(payload.plate or payload.vehiclePlate or payload.dispatchPlate)
    if plate == '' then
        return nil, 'Vehicle plate is required.'
    end

    local seed = hashValue(plate)
    local createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    local model = trim(payload.model or payload.vehicleModel)
    local color = trim(payload.color)
    local vehicleClass = normalizeVehicleClass(payload.vehicleClass, seed)

    return {
        id = ('standalone:%s'):format(formatVehicleId(state.vehicleCounter)),
        vehicle_id = formatVehicleId(state.vehicleCounter),
        plate = plate,
        vin = trim(payload.vin) ~= '' and trim(payload.vin):upper() or buildVin(seed),
        owner_citizen_id = ownerCitizenId,
        model = model ~= '' and model or pickFrom(VEHICLE_MODELS, seed, 2),
        color = color ~= '' and color or pickFrom(VEHICLE_COLORS, seed, 4),
        vehicle_class = vehicleClass,
        registration_status = normalizeRegistrationStatus(payload.registrationStatus or payload.status),
        insurance_status = trim(payload.insuranceStatus) ~= '' and trim(payload.insuranceStatus) or pickFrom({ 'Active', 'Active', 'Active', 'Lapsed' }, seed, 7),
        reg_expiry = trim(payload.regExpiry) ~= '' and trim(payload.regExpiry) or formatExpiry(seed),
        year = trim(payload.year) ~= '' and trim(payload.year) or tostring(2014 + (seed % 12)),
        flags = normalizeFlagList(payload.flags),
        notes = trim(payload.notes) ~= '' and trim(payload.notes) or nil,
        standalone = true,
        generated = payload.generated == true,
        ownerSource = nil,
        createdBySource = source,
        createdAt = createdAt,
        updatedAt = createdAt,
    }
end

local function resolveCitizenForVehicle(source, payload)
    local session = ensureSession(source)
    local citizenId = trim(payload and (payload.citizenId or payload.ownerCitizenId) or '')

    if citizenId == '' then
        citizenId = session.activeCitizenId or session.lastGeneratedCitizenId or ''
    end

    if citizenId == '' then
        return nil, 'Claim a civilian before registering a vehicle.'
    end

    local citizen = state.citizens[citizenId]
    if not citizen then
        return nil, 'Selected civilian was not found.'
    end

    if not session.citizenIds[citizenId] and citizen.createdBySource ~= source and citizen.ownerSource ~= source then
        return nil, 'You can only register vehicles to civilians from your own session.'
    end

    return citizen
end

local function generateCitizen(source, payload)
    local session = ensureSession(source)
    local config = getConfig()
    local maxCitizens = tonumber(config.maxCitizensPerSession) or 8
    local visibleCount = 0

    for _ in pairs(session.citizenIds) do
        visibleCount = visibleCount + 1
    end

    if visibleCount >= maxCitizens then
        return nil, ('Session limit reached (%d civilians).'):format(maxCitizens)
    end

    payload = type(payload) == 'table' and payload or {}

    local fullName = trim(payload.name)
    if fullName == '' then
        local seed = hashValue(('%s:%s:%s'):format(source, GetGameTimer(), visibleCount))
        fullName = ('%s %s'):format(
            pickFrom(FIRST_NAMES, seed, visibleCount),
            pickFrom(LAST_NAMES, seed, visibleCount + 2)
        )
    end

    state.counter = state.counter + 1
    local citizen = buildCitizenRecord(source, fullName)

    state.citizens[citizen.citizen_id] = citizen
    state.citizenOrder[#state.citizenOrder + 1] = citizen.citizen_id
    session.citizenIds[citizen.citizen_id] = true
    session.lastGeneratedCitizenId = citizen.citizen_id

    if payload.claim == true or config.claimOnGenerate == true then
        return setExclusiveClaim(source, citizen.citizen_id)
    end

    return serializeCitizen(citizen, source)
end

local function registerCivilian(source, payload)
    local session = ensureSession(source)
    local config = getConfig()
    local maxCitizens = tonumber(config.maxCitizensPerSession) or 8
    local visibleCount = 0

    for _ in pairs(session.citizenIds) do
        visibleCount = visibleCount + 1
    end

    if visibleCount >= maxCitizens then
        return nil, ('Session limit reached (%d civilians).'):format(maxCitizens)
    end

    payload = type(payload) == 'table' and payload or {}

    local firstName = titleCase(trim(payload.firstName or ''))
    local lastName = titleCase(trim(payload.lastName or ''))

    if firstName == '' or lastName == '' then
        return nil, 'First name and last name are required.'
    end

    local fullName = ('%s %s'):format(firstName, lastName)
    state.counter = state.counter + 1
    local citizen = buildCitizenRecord(source, fullName)

    citizen.first_name = firstName
    citizen.last_name = lastName
    citizen.dob = trim(payload.dob or citizen.dob)
    citizen.nationality = trim(payload.nationality or citizen.nationality)
    citizen.mugshot = trim(payload.mugshot) ~= '' and trim(payload.mugshot) or defaultMugshotUrl()

    if payload.phone then
        citizen.phone = trim(payload.phone)
    end

    if payload.address then
        citizen.address = trim(payload.address)
    end

    if payload.occupation then
        citizen.occupation = trim(payload.occupation)
    end

    citizen.flags = normalizeFlagList(payload.flags)
    if payload.hasWarrant == true then
        citizen.flags[#citizen.flags + 1] = 'wanted'
        citizen.flags = normalizeFlagList(citizen.flags)
    end
    if payload.hasSpeedingPrior == true then
        citizen.flags[#citizen.flags + 1] = 'speeding_prior'
        citizen.flags = normalizeFlagList(citizen.flags)
    end

    if payload.notes then
        local noteText = trim(payload.notes)
        if noteText ~= '' then
            citizen.notes = ('[Self-Registered]: %s'):format(noteText)
        end
    end

    citizen.generated = false
    citizen.createdBySource = source
    citizen.updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

    state.citizens[citizen.citizen_id] = citizen
    state.citizenOrder[#state.citizenOrder + 1] = citizen.citizen_id
    session.citizenIds[citizen.citizen_id] = true
    session.lastGeneratedCitizenId = citizen.citizen_id

    return setExclusiveClaim(source, citizen.citizen_id)
end

local function claimCitizen(source, citizenId)
    return setExclusiveClaim(source, citizenId)
end

local function unclaimCitizen(source, citizenId)
    local id = trim(citizenId)
    local citizen = state.citizens[id]

    if not citizen then
        return nil, 'Citizen not found.'
    end

    if citizen.ownerSource ~= source then
        return nil, 'Only the current owner can unclaim this civilian.'
    end

    citizen.ownerSource = nil
    citizen.claimed = false
    citizen.updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

    local session = ensureSession(source)
    if session.activeCitizenId == id then
        session.activeCitizenId = nil
    end

    return serializeCitizen(citizen, source)
end

local function removeCitizenFromSessions(citizenId)
    for source, session in pairs(state.sessions) do
        session.citizenIds[citizenId] = nil
        if session.activeCitizenId == citizenId then
            session.activeCitizenId = nil
        end
        if session.lastGeneratedCitizenId == citizenId then
            session.lastGeneratedCitizenId = nil
        end
        state.sessions[source] = session
    end
end

local function removeVehicleFromSessions(vehicleId)
    for source, session in pairs(state.sessions) do
        session.vehicleIds[vehicleId] = nil
        state.sessions[source] = session
    end
end

local function detachVehiclesForCitizen(citizenId)
    for i = 1, #state.vehicleOrder do
        local vehicle = state.vehicles[state.vehicleOrder[i]]
        if vehicle and vehicle.owner_citizen_id == citizenId then
            vehicle.owner_citizen_id = nil
            vehicle.ownerSource = nil
            vehicle.updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
        end
    end
end

local function trimOrNil(value)
    local text = trim(value or '')
    if text == '' then
        return nil
    end
    return text
end

--- Update fields for a session-owned standalone civilian (syncs to police MDT via same citizen record).
local function updateCitizenProfile(source, payload)
    payload = type(payload) == 'table' and payload or {}
    local id = trim(payload.citizenId or payload.citizen_id or '')

    if id == '' then
        return nil, 'Citizen ID is required.'
    end

    local citizen = state.citizens[id]

    if not citizen then
        return nil, 'Citizen not found.'
    end

    if citizen.ownerSource and citizen.ownerSource ~= source then
        return nil, 'Only the current owner can edit this civilian.'
    end

    if citizen.createdBySource ~= source and citizen.ownerSource ~= source then
        return nil, 'You can only edit civilians from your own session.'
    end

    if payload.dateOfBirth ~= nil or payload.dob ~= nil then
        citizen.dob = trimOrNil(payload.dateOfBirth or payload.dob)
    end

    if payload.gender ~= nil then
        citizen.gender = trimOrNil(payload.gender)
    end

    if payload.phone ~= nil then
        citizen.phone = trimOrNil(payload.phone)
    end

    if payload.email ~= nil then
        citizen.email = trimOrNil(payload.email)
    end

    if payload.address ~= nil then
        citizen.address = trimOrNil(payload.address)
    end

    if payload.nationality ~= nil then
        citizen.nationality = trimOrNil(payload.nationality)
    end

    if payload.height ~= nil then
        citizen.height = trimOrNil(payload.height)
    end

    if payload.eyeColor ~= nil or payload.eye_color ~= nil then
        citizen.eye_color = trimOrNil(payload.eyeColor or payload.eye_color)
    end

    if payload.bloodType ~= nil or payload.blood_type ~= nil then
        citizen.blood_type = trimOrNil(payload.bloodType or payload.blood_type)
    end

    if payload.emergencyContact ~= nil or payload.emergency_contact ~= nil then
        citizen.emergency_contact = trimOrNil(payload.emergencyContact or payload.emergency_contact)
    end

    if payload.mugshot ~= nil or payload.mugshotUrl ~= nil or payload.photoUrl ~= nil then
        citizen.mugshot = trimOrNil(payload.mugshot or payload.mugshotUrl or payload.photoUrl) or defaultMugshotUrl()
    end

    citizen.updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

    return serializeCitizen(citizen, source)
end

local function deleteCitizen(source, citizenId)
    local id = trim(citizenId)
    local citizen = state.citizens[id]

    if not citizen then
        return nil, 'Citizen not found.'
    end

    if citizen.ownerSource and citizen.ownerSource ~= source then
        return nil, 'Only the current owner can delete this civilian.'
    end

    if citizen.createdBySource ~= source and citizen.ownerSource ~= source then
        return nil, 'You can only delete civilians from your own session.'
    end

    detachVehiclesForCitizen(id)
    state.citizens[id] = nil

    for i = #state.citizenOrder, 1, -1 do
        if state.citizenOrder[i] == id then
            table.remove(state.citizenOrder, i)
            break
        end
    end

    removeCitizenFromSessions(id)

    return true
end

local function registerVehicle(source, payload)
    payload = type(payload) == 'table' and payload or {}
    local citizen, err = resolveCitizenForVehicle(source, payload)
    if not citizen then
        return nil, err
    end

    local plate = normalizePlate(payload.plate or payload.vehiclePlate or payload.dispatchPlate)
    if plate == '' then
        return nil, 'Vehicle plate is required.'
    end

    local session = ensureSession(source)
    local existingId = state.vehicleByPlate[plate]
    local vehicle = existingId and state.vehicles[existingId] or nil
    local updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

    if vehicle and vehicle.ownerSource and vehicle.ownerSource ~= source then
        return nil, 'Vehicle is already registered by another session.'
    end

    if not vehicle then
        state.vehicleCounter = state.vehicleCounter + 1
        vehicle, err = buildVehicleRecord(source, payload, citizen.citizen_id)
        if not vehicle then
            return nil, err
        end

        state.vehicles[vehicle.id] = vehicle
        state.vehicleOrder[#state.vehicleOrder + 1] = vehicle.id
        state.vehicleByPlate[plate] = vehicle.id
    else
        local model = trim(payload.model or payload.vehicleModel)
        local color = trim(payload.color)
        local year = trim(payload.year)
        local vehicleClass = trim(payload.vehicleClass)
        local notes = trim(payload.notes)

        vehicle.owner_citizen_id = citizen.citizen_id
        vehicle.model = model ~= '' and model or vehicle.model
        vehicle.color = color ~= '' and color or vehicle.color
        vehicle.year = year ~= '' and year or vehicle.year
        vehicle.vehicle_class = normalizeVehicleClass(vehicleClass ~= '' and vehicleClass or vehicle.vehicle_class, hashValue(plate))
        vehicle.registration_status = normalizeRegistrationStatus(payload.registrationStatus or payload.status or vehicle.registration_status)
        vehicle.flags = normalizeFlagList(payload.flags or vehicle.flags)
        if notes ~= '' then
            vehicle.notes = notes
        end
        vehicle.updatedAt = updatedAt
    end

    vehicle.owner_citizen_id = citizen.citizen_id
    vehicle.ownerSource = citizen.ownerSource == source and source or nil
    vehicle.updatedAt = updatedAt
    session.vehicleIds[vehicle.id] = true

    return serializeVehicle(vehicle, source)
end

local function deleteVehicle(source, vehicleId)
    local id = trim(vehicleId)
    local vehicle = state.vehicles[id]

    if not vehicle then
        return nil, 'Vehicle not found.'
    end

    if vehicle.createdBySource ~= source and vehicle.ownerSource ~= source then
        return nil, 'You can only delete vehicles from your own session.'
    end

    state.vehicles[id] = nil
    state.vehicleByPlate[vehicle.plate] = nil

    for i = #state.vehicleOrder, 1, -1 do
        if state.vehicleOrder[i] == id then
            table.remove(state.vehicleOrder, i)
            break
        end
    end

    removeVehicleFromSessions(id)

    return true
end

local function searchCitizens(query, limit)
    local needle = trim(query):lower()
    local results = {}

    if needle == '' then
        return results
    end

    for i = 1, #state.citizenOrder do
        local citizen = state.citizens[state.citizenOrder[i]]
        if citizen then
            local haystack = table.concat({
                citizen.citizen_id or '',
                citizen.first_name or '',
                citizen.last_name or '',
                citizen.phone or '',
                citizen.fingerprint or '',
                getCitizenDisplayName(citizen),
            }, ' '):lower()

            if haystack:find(needle, 1, true) then
                results[#results + 1] = serializeCitizen(citizen, 0)
                if limit and #results >= limit then
                    break
                end
            end
        end
    end

    return results
end

local function getCitizenData(citizenId, source)
    local citizen = state.citizens[trim(citizenId)]
    if not citizen then
        return nil
    end

    return {
        citizen = serializeCitizen(citizen, source or 0),
        vehicles = listVehiclesForCitizen(citizen.citizen_id, source or 0),
        licenses = {},
        reports = {},
        warrants = hasFlag(citizen.flags, 'wanted') and {
            {
                id = ('standalone:warrant:%s'):format(citizen.citizen_id),
                citizen_id = citizen.citizen_id,
                citizen_name = getCitizenDisplayName(citizen),
                description = 'Standalone-generated warrant flag.',
                charges = { 'Wanted' },
                status = 'active',
                standalone = true,
            },
        } or {},
        bolos = {},
    }
end

local function getOwnerSource(citizenId)
    local citizen = state.citizens[trim(citizenId)]
    if not citizen then
        return nil
    end

    return citizen.ownerSource
end

local function searchVehicles(query, limit)
    local needle = trim(query):lower()
    local results = {}

    if needle == '' then
        return results
    end

    for i = 1, #state.vehicleOrder do
        local vehicle = state.vehicles[state.vehicleOrder[i]]
        if vehicle then
            local owner = vehicle.owner_citizen_id and state.citizens[vehicle.owner_citizen_id] or nil
            local haystack = table.concat({
                vehicle.plate or '',
                vehicle.vin or '',
                vehicle.model or '',
                vehicle.color or '',
                owner and getCitizenDisplayName(owner) or '',
            }, ' '):lower()

            if haystack:find(needle, 1, true) then
                results[#results + 1] = serializeVehicle(vehicle, 0)
                if limit and #results >= limit then
                    break
                end
            end
        end
    end

    return results
end

local function getVehicleData(vehicleId, source)
    local id = trim(vehicleId)
    local vehicle = state.vehicles[id]

    if not vehicle then
        vehicle = state.vehicles[state.vehicleByPlate[normalizePlate(id)] or '']
    end

    if not vehicle then
        return nil
    end

    return {
        vehicle = serializeVehicle(vehicle, source or 0),
        impounds = {},
    }
end

local function clearPlayer(source)
    local cleanupCitizenIds = {}
    local cleanupVehicleIds = {}

    for citizenId, citizen in pairs(state.citizens) do
        if citizen.createdBySource == source or citizen.ownerSource == source then
            cleanupCitizenIds[#cleanupCitizenIds + 1] = citizenId
        end
    end

    for vehicleId, vehicle in pairs(state.vehicles) do
        if vehicle.createdBySource == source or vehicle.ownerSource == source then
            cleanupVehicleIds[#cleanupVehicleIds + 1] = vehicleId
        end
    end

    for i = 1, #cleanupCitizenIds do
        deleteCitizen(source, cleanupCitizenIds[i])
    end

    for i = 1, #cleanupVehicleIds do
        deleteVehicle(source, cleanupVehicleIds[i])
    end

    state.sessions[source] = nil
end

return {
    ensureSession = ensureSession,
    generateCitizen = generateCitizen,
    registerCivilian = registerCivilian,
    claimCitizen = claimCitizen,
    unclaimCitizen = unclaimCitizen,
    updateCitizenProfile = updateCitizenProfile,
    deleteCitizen = deleteCitizen,
    registerVehicle = registerVehicle,
    deleteVehicle = deleteVehicle,
    getCivilianProfile = getCivilianProfile,
    getState = getState,
    listOwnedCitizens = listOwnedCitizens,
    listAvailableCitizens = listAvailableCitizens,
    listVehiclesForCitizen = listVehiclesForCitizen,
    getCurrentVehicles = getCurrentVehicles,
    searchCitizens = searchCitizens,
    getCitizenData = getCitizenData,
    getOwnerSource = getOwnerSource,
    searchVehicles = searchVehicles,
    getVehicleData = getVehicleData,
    handlePlayerDropped = clearPlayer,
}
