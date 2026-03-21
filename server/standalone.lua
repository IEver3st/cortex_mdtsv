local state = {
    citizens = {},
    citizenOrder = {},
    sessions = {},
    counter = 0,
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

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$') or ''
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
        }
    end

    return state.sessions[source]
end

local function formatCitizenId(index)
    return ('%s-%04d'):format(getCitizenPrefix(), index)
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
        mugshot = nil,
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

local function serializeCitizen(citizen, source)
    if not citizen then
        return nil
    end

    local session = ensureSession(source)
    local fullName = ('%s %s'):format(citizen.first_name or '', citizen.last_name or ''):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''

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
        mugshot = citizen.mugshot,
        fingerprint = citizen.fingerprint,
        flags = citizen.flags or {},
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
        return state.citizens[session.activeCitizenId]
    end

    for i = 1, #state.citizenOrder do
        local citizenId = state.citizenOrder[i]
        local citizen = state.citizens[citizenId]

        if citizen and citizen.ownerSource == source then
            session.activeCitizenId = citizenId
            return citizen
        end
    end

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
        activeCitizenId = session.activeCitizenId,
        civilian = serializeCitizen(activeCitizen, source) or getCivilianProfile(source),
        standaloneEnabled = true,
        maxCitizensPerSession = tonumber(config.maxCitizensPerSession) or 8,
    }
end

local function getState(source)
    return buildStatePayload(source)
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
        citizen.claimed = true
        citizen.ownerSource = source
        setCitizenActive(source, citizen.citizen_id)
    end

    return serializeCitizen(citizen, source)
end

local function claimCitizen(source, citizenId)
    local citizen = state.citizens[trim(citizenId)]

    if not citizen then
        return nil, 'Citizen not found.'
    end

    if citizen.ownerSource and citizen.ownerSource ~= source then
        return nil, 'Citizen is already claimed by another session.'
    end

    local session = ensureSession(source)
    session.citizenIds[citizen.citizen_id] = true
    citizen.ownerSource = source
    citizen.claimed = true
    citizen.updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    setCitizenActive(source, citizen.citizen_id)

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

local function clearPlayer(source)
    local cleanupIds = {}

    for citizenId, citizen in pairs(state.citizens) do
        if citizen.createdBySource == source or citizen.ownerSource == source then
            cleanupIds[#cleanupIds + 1] = citizenId
        end
    end

    for i = 1, #cleanupIds do
        deleteCitizen(source, cleanupIds[i])
    end

    state.sessions[source] = nil
end

return {
    ensureSession = ensureSession,
    generateCitizen = generateCitizen,
    claimCitizen = claimCitizen,
    deleteCitizen = deleteCitizen,
    getCivilianProfile = getCivilianProfile,
    getState = getState,
    listOwnedCitizens = listOwnedCitizens,
    listAvailableCitizens = listAvailableCitizens,
    handlePlayerDropped = clearPlayer,
}
