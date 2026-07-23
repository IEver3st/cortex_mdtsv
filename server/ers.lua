local ERS = {}

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$') or ''
end

local function lower(value)
    return trim(value):lower()
end

local PLACEHOLDER_VALUES = {
    unknown = true,
    unavailable = true,
    none = true,
    null = true,
    ['n/a'] = true,
    ['not available'] = true,
}

local function isPlaceholder(value)
    return PLACEHOLDER_VALUES[lower(value)] == true
end

local function readKey(container, keys, allowPlaceholder)
    if type(container) ~= 'table' then
        return ''
    end

    for i = 1, #keys do
        local value = container[keys[i]]
        if value ~= nil then
            local text = trim(value)
            if text ~= '' and (allowPlaceholder or not isPlaceholder(text)) then
                return text
            end
        end
    end

    for key, value in pairs(container) do
        local normalizedKey = lower(key):gsub('[^a-z0-9]', '')
        for i = 1, #keys do
            if normalizedKey == lower(keys[i]):gsub('[^a-z0-9]', '') then
                local text = trim(value)
                if text ~= '' and (allowPlaceholder or not isPlaceholder(text)) then
                    return text
                end
            end
        end
    end

    return ''
end

local function readNested(containers, keys, allowPlaceholder)
    for i = 1, #containers do
        local value = readKey(containers[i], keys, allowPlaceholder)
        if value ~= '' then
            return value
        end
    end

    return ''
end

local function splitName(value)
    local name = trim(value)
    if name == '' then
        return '', ''
    end

    local firstName, lastName = name:match('^(%S+)%s+(.+)$')
    if firstName and lastName then
        return trim(firstName), trim(lastName)
    end

    return name, ''
end

local function normalizeLicenseStatus(value)
    local status = lower(value)
    if status == '' then
        return ''
    end

    if status == 'true' or status == 'yes' or status == 'active' or status == 'valid' then
        return 'valid'
    end

    if status == 'false' or status == 'no' or status == 'invalid' or status == 'none' then
        return 'invalid'
    end

    if status == 'expired' or status == 'suspended' or status == 'revoked' then
        return status
    end

    if status:find('stolen', 1, true) then
        return 'stolen'
    end

    return status
end

local function appendLicense(licenses, seen, licenseType, status, validUntil)
    local label = trim(licenseType)
    if label == '' then
        return
    end

    local normalizedStatus = normalizeLicenseStatus(status)
    if normalizedStatus == '' then
        normalizedStatus = 'valid'
    end

    local key = lower(label)
    if seen[key] then
        return
    end

    seen[key] = true
    licenses[#licenses + 1] = {
        type = label,
        status = normalizedStatus,
        expires_at = trim(validUntil),
        source = 'night_ers',
    }
end

local function collectLicenses(containers)
    local licenses = {}
    local seen = {}

    for i = 1, #containers do
        local container = containers[i]
        if type(container) == 'table' then
            for _, key in ipairs({ 'licenses', 'Licenses', 'licences', 'Licences' }) do
                local raw = container[key]
                if type(raw) == 'table' then
                    for licenseKey, licenseValue in pairs(raw) do
                        if type(licenseValue) == 'table' then
                            appendLicense(
                                licenses,
                                seen,
                                licenseValue.type or licenseValue.name or licenseValue.label or licenseKey,
                                licenseValue.status or licenseValue.state or licenseValue.valid or licenseValue.value,
                                licenseValue.expires_at or licenseValue.expiresAt or licenseValue.expiry or licenseValue.validUntil
                            )
                        else
                            appendLicense(licenses, seen, licenseKey, licenseValue)
                        end
                    end
                end
            end
        end
    end

    local mappedKeys = {
        { 'Driver', { 'DriverLicense', 'driverLicense', 'driver_license', 'DrivingLicense', 'drivingLicense', 'DrivingLicence', 'drivingLicence' } },
        { 'Weapon', { 'WeaponLicense', 'weaponLicense', 'weapon_license', 'FirearmLicense', 'firearmLicense' } },
        { 'Pilot', { 'PilotLicense', 'pilotLicense', 'pilot_license' } },
        { 'Hunting', { 'HuntingLicense', 'huntingLicense', 'hunting_license' } },
        { 'Fishing', { 'FishingLicense', 'fishingLicense', 'fishing_license' } },
        { 'Business', { 'BusinessLicense', 'businessLicense', 'business_license' } },
    }

    for i = 1, #mappedKeys do
        local label = mappedKeys[i][1]
        local value = readNested(containers, mappedKeys[i][2], true)
        if value ~= '' then
            appendLicense(licenses, seen, label, value)
        end
    end

    local stolen = readNested(containers, { 'ReportedStolen', 'reportedStolen', 'reported_stolen', 'Stolen', 'stolen' }, true)
    if normalizeLicenseStatus(stolen) == 'valid' or lower(stolen) == 'stolen' then
        appendLicense(licenses, seen, 'Reported Stolen', 'stolen')
    end

    return licenses
end

local function sanitizeToken(value)
    local token = trim(value):upper():gsub('[^A-Z0-9%-_]', '')
    if #token > 48 then
        token = token:sub(1, 48)
    end
    return token
end

local function hashValue(value)
    local hash = 2166136261
    local text = tostring(value or '')

    for i = 1, #text do
        hash = ((hash ~ text:byte(i)) * 16777619) & 0xffffffff
    end

    return ('%08X'):format(hash)
end

local function encodeForHash(value)
    if type(json) == 'table' and type(json.encode) == 'function' then
        local ok, encoded = pcall(json.encode, value)
        if ok and encoded then
            return encoded
        end
    end

    return tostring(value or '')
end

local function getConfig()
    return type(Config.ErsIntegration) == 'table' and Config.ErsIntegration or {}
end

local function isEnabled()
    local config = getConfig()
    return config.enabled ~= false
end

local function getCitizenPrefix()
    local prefix = sanitizeToken(getConfig().citizenPrefix)
    return prefix ~= '' and prefix or 'ERS'
end

local function usesLocalMode()
    return type(CortexDatabase) == 'table' and CortexDatabase.mode ~= 'qbx'
end

local function normalizePlate(value)
    return trim(value):upper():gsub('%s+', '')
end

local function getContainers(data)
    data = type(data) == 'table' and data or {}
    local containers = { data }
    local keys = {
        'identity',
        'Identity',
        'person',
        'Person',
        'personal',
        'Personal',
        'personalData',
        'PersonalData',
        'citizen',
        'Citizen',
        'profile',
        'Profile',
        'metadata',
        'Metadata',
        'data',
        'Data',
        'license',
        'License',
        'idCard',
        'IdCard',
        'database',
        'Database',
    }

    for i = 1, #keys do
        if type(data[keys[i]]) == 'table' then
            containers[#containers + 1] = data[keys[i]]
        end
    end

    return containers
end

local function appendContainers(target, containers)
    for i = 1, #containers do
        target[#target + 1] = containers[i]
    end

    return target
end

function ERS.normalizePed(pedData, context)
    pedData = type(pedData) == 'table' and pedData or {}
    local contextValue = context
    local contextText = type(contextValue) == 'table' and '' or trim(contextValue)
    context = type(context) == 'table' and context or {}

    local containers = appendContainers(getContainers(pedData), getContainers(context))
    local firstName = readNested(containers, { 'FirstName', 'firstName', 'firstname', 'first_name', 'givenName', 'given_name', 'forename', 'first', 'nameFirst' })
    local lastName = readNested(containers, { 'LastName', 'lastName', 'lastname', 'last_name', 'surname', 'familyName', 'family_name', 'secondName', 'second_name', 'last', 'nameLast' })

    if firstName == '' and lastName == '' then
        firstName, lastName = splitName(readNested(containers, { 'FullName', 'fullName', 'full_name', 'Name', 'name', 'displayName', 'display_name', 'label', 'fictiveName' }))
    end

    if firstName == '' then
        firstName = 'Unknown'
    end

    local explicitMdtId = sanitizeToken(readNested(containers, {
        'mdtCitizenId',
        'mdt_citizen_id',
        'MdtCitizenId',
        'citizenId',
        'citizen_id',
        'citizenID',
        'CitizenId',
    }))
    local externalKey = readNested(containers, {
        'IdNumber',
        'idNumber',
        'id_number',
        'IdentityNumber',
        'identityNumber',
        'identity_number',
        'LicenseNumber',
        'licenseNumber',
        'license_number',
        'DriverLicense',
        'driverLicense',
        'driver_license',
        'DocumentNumber',
        'documentNumber',
        'document_number',
        'CardNumber',
        'cardNumber',
        'card_number',
        'ErsId',
        'ersId',
        'ers_id',
        'NpcId',
        'npcId',
        'npc_id',
        'PedId',
        'pedId',
        'ped_id',
        'CharacterId',
        'characterId',
        'character_id',
        'IdentityId',
        'identityId',
        'identity_id',
        'NetId',
        'netId',
        'net_id',
        'NetworkId',
        'networkId',
        'network_id',
        'Handle',
        'handle',
        'Entity',
        'entity',
        'id',
    })

    local dob = readNested(containers, { 'DOB', 'Dob', 'dob', 'DateOfBirth', 'dateOfBirth', 'date_of_birth', 'Birthdate', 'birthdate' })
    local phone = readNested(containers, { 'Phone', 'phone', 'PhoneNumber', 'phoneNumber', 'phone_number', 'telephone' })
    local interactionKey = readNested({ context }, { 'InteractionId', 'interactionId', 'interaction_id', 'CallId', 'callId', 'call_id' })

    if externalKey == '' then
        externalKey = ('%s:%s:%s:%s:%s'):format(
            firstName,
            lastName,
            dob,
            phone,
            interactionKey ~= '' and interactionKey or contextText
        )
    end

    local citizenId = explicitMdtId
    if citizenId == '' then
        local hasIdentityFields = firstName ~= 'Unknown' or lastName ~= '' or dob ~= '' or phone ~= ''
        local token = hasIdentityFields and sanitizeToken(externalKey) or ''
        if token == '' or #token > 24 then
            local hashSource = hasIdentityFields and externalKey or ('%s:%s'):format(encodeForHash(pedData), encodeForHash(context))
            token = hashValue(hashSource ~= '' and hashSource or externalKey)
        end
        citizenId = ('%s-%s'):format(getCitizenPrefix(), token)
    end

    local notes = readNested(containers, { 'Notes', 'notes', 'note', 'Description', 'description', 'Details', 'details', 'flag_description' })
    local sourceTag = readNested(containers, { 'Source', 'source', 'Resource', 'resource' })
    if sourceTag == '' then
        sourceTag = 'night_ers'
    end

    local nationality = readNested(containers, { 'Nationality', 'nationality', 'Nation', 'nation', 'Country', 'country' })
    local address = readNested(containers, { 'Address', 'address', 'HomeAddress', 'homeAddress', 'home_address', 'Residence', 'residence' })
    local email = readNested(containers, { 'Email', 'email', 'E-mail', 'e-mail', 'EmailAddress', 'emailAddress', 'email_address' })
    local licenses = collectLicenses(containers)

    return {
        id = citizenId,
        citizenId = citizenId,
        citizen_id = citizenId,
        firstName = firstName,
        first_name = firstName,
        lastName = lastName,
        last_name = lastName,
        dob = dob,
        gender = readNested(containers, { 'Gender', 'gender', 'Sex', 'sex' }),
        phone = phone,
        mugshot = readNested(containers, { 'Mugshot', 'mugshot', 'MugshotUrl', 'mugshotUrl', 'mugshot_url', 'PhotoUrl', 'photoUrl', 'photo_url', 'Image', 'image' }),
        fingerprint = readNested(containers, { 'Fingerprint', 'fingerprint', 'FingerprintId', 'fingerprintId', 'fingerprint_id' }),
        occupation = readNested(containers, { 'Occupation', 'occupation', 'Job', 'job', 'Profession', 'profession' }),
        nationality = nationality,
        address = address,
        email = email,
        notes = notes,
        properties = {
            ersPersonalDetails = {
                nationality = nationality,
                address = address,
                email = email,
            },
            ersLicenses = licenses,
        },
        licenses = licenses,
        flags = {},
        source = sourceTag,
        ers = true,
        externalKey = externalKey,
        external_key = externalKey,
        raw = pedData,
    }
end

function ERS.normalizeVehicle(vehicleData, ownerCitizenId)
    vehicleData = type(vehicleData) == 'table' and vehicleData or {}
    local containers = getContainers(vehicleData)
    local plate = normalizePlate(readNested(containers, { 'plate', 'licensePlate', 'license_plate', 'numberPlate', 'number_plate' }))

    if plate == '' then
        return nil, 'Missing vehicle plate.'
    end

    return {
        id = plate,
        vehicleId = plate,
        vehicle_id = plate,
        plate = plate,
        vin = readNested(containers, { 'vin', 'VIN' }),
        ownerCitizenId = ownerCitizenId,
        owner_citizen_id = ownerCitizenId,
        model = readNested(containers, { 'model', 'modelName', 'model_name', 'name', 'displayName' }),
        color = readNested(containers, { 'color', 'primaryColor', 'primary_color' }),
        vehicleClass = readNested(containers, { 'vehicleClass', 'vehicle_class', 'class' }),
        vehicle_class = readNested(containers, { 'vehicleClass', 'vehicle_class', 'class' }),
        registrationStatus = getConfig().registrationStatus or 'valid',
        registration_status = getConfig().registrationStatus or 'valid',
        flags = {},
        source = 'night_ers',
        ers = true,
        raw = vehicleData,
    }
end

local function upsertLocalCitizen(citizen)
    local localMode = rawget(_G, 'CortexLocalMode')
    if type(localMode) ~= 'table' or type(localMode.upsertExternalCitizen) ~= 'function' then
        return nil, 'LocalMode ERS upsert is unavailable.'
    end

    return localMode.upsertExternalCitizen(citizen)
end

local function upsertSqlCitizen(citizen)
    citizen.mugshot = trim(citizen.mugshot) ~= '' and trim(citizen.mugshot) or trim(Config and Config.DefaultMugshot or '')

    MySQL.query.await([[
        INSERT INTO mdt_citizens
            (citizen_id, first_name, last_name, dob, gender, phone, mugshot, fingerprint, occupation, properties, flags, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            first_name = VALUES(first_name),
            last_name = VALUES(last_name),
            dob = COALESCE(NULLIF(VALUES(dob), ''), dob),
            gender = COALESCE(NULLIF(VALUES(gender), ''), gender),
            phone = COALESCE(NULLIF(VALUES(phone), ''), phone),
            mugshot = COALESCE(NULLIF(VALUES(mugshot), ''), mugshot),
            fingerprint = COALESCE(NULLIF(VALUES(fingerprint), ''), fingerprint),
            occupation = COALESCE(NULLIF(VALUES(occupation), ''), occupation),
            properties = VALUES(properties),
            flags = VALUES(flags),
            notes = COALESCE(NULLIF(VALUES(notes), ''), notes)
    ]], {
        citizen.citizen_id,
        citizen.first_name,
        citizen.last_name,
        citizen.dob,
        citizen.gender,
        citizen.phone,
        citizen.mugshot,
        citizen.fingerprint,
        citizen.occupation,
        json.encode(citizen.properties or {}),
        json.encode(citizen.flags or {}),
        citizen.notes,
    })

    if type(citizen.licenses) == 'table' and #citizen.licenses > 0 then
        MySQL.update.await('DELETE FROM mdt_citizen_licenses WHERE citizen_id = ?', {
            citizen.citizen_id,
        })

        for i = 1, #citizen.licenses do
            local license = citizen.licenses[i]
            local status = normalizeLicenseStatus(license.status)
            if status == 'invalid' or status == 'stolen' then
                status = 'revoked'
            elseif status == '' then
                status = 'valid'
            end
            MySQL.insert.await('INSERT INTO mdt_citizen_licenses (citizen_id, type, status, expires_at) VALUES (?, ?, ?, ?)', {
                citizen.citizen_id,
                license.type,
                status,
                license.expires_at ~= '' and license.expires_at or nil,
            })
        end
    end

    return citizen
end

function ERS.upsertPed(pedData, context)
    if not isEnabled() then
        return nil, 'ERS integration disabled.'
    end

    local citizen = ERS.normalizePed(pedData, context)
    if usesLocalMode() then
        return upsertLocalCitizen(citizen)
    end

    return upsertSqlCitizen(citizen)
end

local function upsertLocalVehicle(vehicle)
    local localMode = rawget(_G, 'CortexLocalMode')
    if type(localMode) ~= 'table' or type(localMode.upsertExternalVehicle) ~= 'function' then
        return nil, 'LocalMode ERS vehicle upsert is unavailable.'
    end

    return localMode.upsertExternalVehicle(vehicle)
end

local function upsertSqlVehicle(vehicle)
    MySQL.query.await([[
        INSERT INTO mdt_vehicles
            (plate, vin, owner_citizen_id, model, color, vehicle_class, registration_status, flags, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            vin = COALESCE(NULLIF(VALUES(vin), ''), vin),
            owner_citizen_id = COALESCE(NULLIF(VALUES(owner_citizen_id), ''), owner_citizen_id),
            model = COALESCE(NULLIF(VALUES(model), ''), model),
            color = COALESCE(NULLIF(VALUES(color), ''), color),
            vehicle_class = COALESCE(NULLIF(VALUES(vehicle_class), ''), vehicle_class),
            registration_status = VALUES(registration_status),
            flags = VALUES(flags),
            notes = COALESCE(NULLIF(VALUES(notes), ''), notes)
    ]], {
        vehicle.plate,
        vehicle.vin,
        vehicle.owner_citizen_id,
        vehicle.model,
        vehicle.color,
        vehicle.vehicle_class,
        vehicle.registration_status,
        json.encode(vehicle.flags or {}),
        vehicle.notes,
    })

    return vehicle
end

function ERS.upsertVehicle(vehicleData, ownerCitizenId)
    if not isEnabled() then
        return nil, 'ERS integration disabled.'
    end

    if getConfig().upsertVehicles == false then
        return nil, 'ERS vehicle upsert disabled.'
    end

    local vehicle, err = ERS.normalizeVehicle(vehicleData, ownerCitizenId)
    if not vehicle then
        return nil, err
    end

    if usesLocalMode() then
        return upsertLocalVehicle(vehicle)
    end

    return upsertSqlVehicle(vehicle)
end

local function resolveSource(explicitSource)
    local value = tonumber(explicitSource)
    if value and value > 0 then
        return value
    end

    value = tonumber(source)
    if value and value > 0 then
        return value
    end

    return nil
end

local function handlePedInteraction(eventName, explicitSource, pedData, context, vehicleData)
    local playerSource = resolveSource(explicitSource)
    local citizen, citizenErr = ERS.upsertPed(pedData, context)

    if not citizen then
        print(('[cortex_mdt] ERS ped upsert failed from %s: %s'):format(eventName, tostring(citizenErr)))
        return
    end

    local vehicle = nil
    if type(vehicleData) == 'table' then
        local vehicleResult, vehicleErr = ERS.upsertVehicle(vehicleData, citizen.citizen_id)
        if not vehicleResult and vehicleErr ~= 'Missing vehicle plate.' then
            print(('[cortex_mdt] ERS vehicle upsert failed from %s: %s'):format(eventName, tostring(vehicleErr)))
        end
        vehicle = vehicleResult
    end

    TriggerEvent('cortex_mdt:ers:pedUpserted', playerSource, citizen, vehicle, {
        event = eventName,
        context = context,
    })
end

RegisterServerEvent('ErsIntegration::OnFirstNPCInteraction')
AddEventHandler('ErsIntegration::OnFirstNPCInteraction', function(src, pedData, context)
    handlePedInteraction('ErsIntegration::OnFirstNPCInteraction', src, pedData, context)
end)

RegisterServerEvent('ErsIntegration::OnPullover')
AddEventHandler('ErsIntegration::OnPullover', function(pedData, vehicleData)
    handlePedInteraction('ErsIntegration::OnPullover', source, pedData, nil, vehicleData)
end)

RegisterServerEvent('ErsIntegration::OnFirstVehicleInteraction')
AddEventHandler('ErsIntegration::OnFirstVehicleInteraction', function(src, vehicleData, context)
    local ownerCitizenId = type(context) == 'table' and trim(context.citizenId or context.citizen_id) or ''
    local vehicle, err = ERS.upsertVehicle(vehicleData, ownerCitizenId ~= '' and ownerCitizenId or nil)

    if not vehicle then
        print(('[cortex_mdt] ERS vehicle interaction ignored: %s'):format(tostring(err)))
        return
    end

    TriggerEvent('cortex_mdt:ers:vehicleUpserted', resolveSource(src), vehicle, {
        event = 'ErsIntegration::OnFirstVehicleInteraction',
        context = context,
    })
end)

exports('upsertErsPed', function(pedData, context)
    return ERS.upsertPed(pedData, context)
end)

exports('upsertErsVehicle', function(vehicleData, ownerCitizenId)
    return ERS.upsertVehicle(vehicleData, ownerCitizenId)
end)

_G.CortexMdtErsIntegration = ERS
