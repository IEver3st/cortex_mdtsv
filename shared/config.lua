-- Cortex MDT Configuration
Config = {}

-- Active framework mode.
-- Supported values: 'auto', 'standalone', 'qbx', 'ers'
Config.FrameworkMode = 'standalone'

-- Auto-detect priority used when FrameworkMode = 'auto'
Config.FrameworkAutoDetectPriority = { 'ers', 'qbx', 'standalone' }

-- Backwards-compatible alias.
Config.Framework = Config.FrameworkMode

-- Server callback access policy. In QBX mode, officer access is limited to
-- jobs mapped into Config.Departments. In ERS mode, an active configured
-- service shift is required. Standalone mode remains open by default; set
-- standaloneOfficerAce to an ACE string to restrict the officer portal.
-- Administrative mutations always require adminAce.
Config.Access = {
    standaloneOfficerAce = false,
    adminAce = 'cortex_mdt.admin',
}

-- Command to open the MDT
Config.OpenCommand = 'mdt'

-- Command to switch into civilian mode.
Config.CivilianCommand = 'civilian'

-- Command to switch into officer duty mode.
Config.PoliceCommand = 'police'

-- Backwards-compatible aliases used by older docs/config snippets.
Config.civilianCommand = Config.CivilianCommand
Config.policeCommand = Config.PoliceCommand

-- Keybind to open the MDT (https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/)
Config.OpenKey = 'F6'

-- Ped emote while MDT NUI focused (needs emote resource: EmoteCommandStart / EmoteCancel exports, e.g. rpemotes-reborn).
-- Set to false to disable. resource = 'auto' uses first started in: rpemotes, rpemotes-reborn.
Config.MDTTabletEmote = {
    enabled = true,
    emoteName = 'tablet2',
    resource = 'auto',
}

-- Resource names used by the auto-detector.
Config.FrameworkResources = {
    qbx = 'qbx_core',
    ers = 'night_ers',
    ersFallbacks = {
        'EmergencyResponseSimulator',
        'ers',
    },
}

-- Framework modes that require the SQL backend to be available at startup.
Config.DatabaseRequiredModes = {
    qbx = true,
}

Config.StandaloneCivilianMode = {
    enabled = true,
    citizenPrefix = 'STN',
    maxCitizensPerSession = 64,
    claimOnGenerate = true,
}

-- Durable JSON storage used whenever the MDT is not using its SQL backend.
-- Writes are verified and atomically replaced with a recoverable .bak copy.
Config.StandalonePersistence = {
    enabled = true,
    debounceMs = 350,
}

-- Default citizen mugshot used whenever a player/citizen record has no custom image.
Config.DefaultMugshot = 'default-avatar.svg'

-- File-backed audit logs. Stored as daily NDJSON under data/audit.
-- Change retentionDays to choose how long logs stay on disk.
Config.AuditLogs = {
    enabled = true,
    retentionDays = 14,
    maxDailyBytes = 5 * 1024 * 1024,
    maxDetailBytes = 2048,
    purgeLookbackDays = 365,
}

-- ERS/Night ERS NPC intake. ERS peds become MDT citizens under this prefix.
Config.ErsIntegration = {
    enabled = true,
    citizenPrefix = 'ERS',
    upsertVehicles = true,
    registrationStatus = 'valid',
}

-- Departments available in the MDT
Config.Departments = {
    ['police'] = {
        label = 'Los Santos Police Department',
        short = 'LSPD',
    },
    ['sheriff'] = {
        label = 'Blaine County Sheriff Office',
        short = 'BCSO',
    },
    ['highway'] = {
        label = 'San Andreas Highway Patrol',
        short = 'SAHP',
    },
    ['ems'] = {
        label = 'Los Santos Emergency Medical Services',
        short = 'EMS',
    },
    ['fire'] = {
        label = 'Los Santos Fire Department',
        short = 'LSFD',
    },
    ['tow'] = {
        label = 'San Andreas Towing Services',
        short = 'TOW',
    },
}

-- Default department if none is found
Config.DefaultDepartment = 'police'

-- Maps framework job/service keys to MDT department entries.
Config.DepartmentAliases = {
    ['police'] = 'police',
    ['leo'] = 'police',
    ['lspd'] = 'police',
    ['bcso'] = 'sheriff',
    ['sheriff'] = 'sheriff',
    ['state'] = 'highway',
    ['sahp'] = 'highway',
    ['ambulance'] = 'ems',
    ['ems'] = 'ems',
    ['fire'] = 'fire',
    ['tow'] = 'tow',
}

-- Default ranks used when the active mode does not provide one.
Config.ServiceRanks = {
    ['police'] = 'Officer',
    ['sheriff'] = 'Deputy',
    ['highway'] = 'Trooper',
    ['ambulance'] = 'Paramedic',
    ['ems'] = 'Paramedic',
    ['fire'] = 'Firefighter',
    ['tow'] = 'Operator',
}

-- Ranks available per department (exposed to the NUI via getConfig)
Config.Ranks = {
    ['police'] = {
        'Cadet', 'Officer', 'Senior Officer', 'Corporal',
        'Sergeant', 'Lieutenant', 'Captain', 'Commander',
        'Assistant Chief', 'Chief',
    },
    ['sheriff'] = {
        'Cadet', 'Deputy', 'Senior Deputy', 'Corporal',
        'Sergeant', 'Lieutenant', 'Captain', 'Under-Sheriff', 'Sheriff',
    },
    ['highway'] = {
        'Cadet', 'Trooper', 'Senior Trooper', 'Corporal',
        'Sergeant', 'Lieutenant', 'Captain', 'Commissioner',
    },
    ['ems'] = {
        'EMT', 'Paramedic', 'Senior Paramedic', 'Supervisor',
        'Lieutenant', 'Captain', 'Director',
    },
    ['fire'] = {
        'Probationary', 'Firefighter', 'Senior Firefighter',
        'Engineer', 'Captain', 'Battalion Chief', 'Chief',
    },
    ['tow'] = {
        'Trainee', 'Operator', 'Senior Operator', 'Supervisor', 'Manager',
    },
}

-- Officer certifications that can be assigned from Admin
Config.Certifications = {
    'FTO',
    'K9',
    'SWAT',
    'Detective',
    'Air Unit',
    'Marine Unit',
    'Bomb Squad',
    'Hostage Negotiator',
    'Tow Certified',
    'Hazmat',
    'Trauma Surgeon',
    'Paramedic Clearance',
}

-- Report templates available when creating a new report
Config.ReportTemplates = {
    { id = 'general',           label = 'General Report' },
    { id = 'arrest',            label = 'Arrest Report' },
    { id = 'traffic_stop',      label = 'Traffic Stop' },
    { id = 'use_of_force',      label = 'Use of Force' },
    { id = 'pursuit',           label = 'Pursuit Report' },
    { id = 'missing_person',    label = 'Missing Person' },
    { id = 'officer_involved',  label = 'Officer-Involved Shooting' },
    { id = 'evidence_log',      label = 'Evidence Log' },
    { id = 'field_interview',   label = 'Field Interview' },
}

-- Flags that can be applied to citizens
Config.CitizenFlags = {
    { id = 'wanted',          label = 'Wanted',            color = '#f87171' },
    { id = 'armed',           label = 'Armed & Dangerous', color = '#fb923c' },
    { id = 'flight_risk',     label = 'Flight Risk',       color = '#fbbf24' },
    { id = 'mental_health',   label = 'Mental Health',     color = '#a78bfa' },
    { id = 'gang_affiliated', label = 'Gang Affiliated',   color = '#f472b6' },
    { id = 'parole',          label = 'On Parole',         color = '#60a5fa' },
    { id = 'probation',       label = 'On Probation',      color = '#60a5fa' },
    { id = 'informant',       label = 'Confidential Informant', color = '#34d399' },
    { id = 'officer',         label = 'Law Enforcement',   color = '#22d3ee' },
}

-- Evidence types available when logging a new piece of evidence
Config.EvidenceTypes = {
    { id = 'general',     label = 'General' },
    { id = 'weapon',      label = 'Weapon' },
    { id = 'firearm',     label = 'Firearm' },
    { id = 'drug',        label = 'Narcotics / Drug' },
    { id = 'clothing',    label = 'Clothing / Fabric' },
    { id = 'document',    label = 'Document' },
    { id = 'photo',       label = 'Photo / Video' },
    { id = 'biological',  label = 'Biological (DNA/Blood)' },
    { id = 'digital',     label = 'Digital Media' },
    { id = 'vehicle',     label = 'Vehicle Part' },
    { id = 'fingerprint', label = 'Fingerprint' },
    { id = 'casing',      label = 'Bullet Casing' },
    { id = 'other',       label = 'Other' },
}

-- Available impound lot locations
Config.ImpoundLots = {
    { id = 'downtown',   label = 'Downtown Lot',         address = 'Davis Ave & Innocence Blvd' },
    { id = 'sandy',      label = 'Sandy Shores Lot',     address = 'Alhambra Dr, Sandy Shores' },
    { id = 'paleto',     label = 'Paleto Bay Lot',       address = 'Paleto Blvd, Paleto Bay' },
    { id = 'police_hq',  label = 'LSPD HQ Impound',     address = 'Mission Row PD Basement' },
    { id = 'sheriff_hq', label = 'BCSO HQ Impound',     address = 'BCSO Station, Sandy Shores' },
}

-- Unit status options shown on the Units page
Config.UnitStatuses = {
    { id = 'available',   label = 'Available',     color = '#34d399' },
    { id = 'busy',        label = 'Busy',          color = '#fbbf24' },
    { id = 'en_route',    label = 'En Route',      color = '#60a5fa' },
    { id = 'on_scene',    label = 'On Scene',      color = '#a78bfa' },
    { id = 'emergency',   label = 'Emergency',     color = '#f87171' },
    { id = 'off_duty',    label = 'Off Duty',      color = '#6b7280' },
}

-- Dispatch page configuration
Config.Dispatch = {
    enabled = true,
    authoritativeBridge = 'cortex-dispatch',
    showClosedCalls = true,
    detailsParity = true,
    panicCooldownSeconds = 30,
    unitUpdateIntervalMs = 1000,
    bridgeRefreshDebounceMs = 1200,
    allowExternalLifecycleReadOnly = true,
    map = {
        -- Same Rockstar tile system and projection used by ox_mdt dispatch.
        tileUrl = 'https://s.rsg.sc/sc/images/games/GTAV/map/game/{z}/{x}/{y}.jpg',
        minZoom = 2,
        maxZoom = 7,
        startZoom = 5,
    },
    bridges = {
        ['cortex-dispatch'] = true,
        ['night_ers'] = true,
        ['ps-dispatch'] = true,
    },
    psDispatch = {
        jobs = { 'leo' },
        panicCodeName = 'officerdown',
        panicCode = '10-99',
        trafficStopCodeName = 'trafficstop',
        trafficStopCode = '10-11',
    },
}

-- CCTV and bodycam page configuration
Config.CCTV = {
    enabled = true,
    -- On start: INSERT missing cam_id rows from data/cctv_presets.json (ps-mdt qbx.sql seed coords).
    seedPresetCameras = true,
    adminAce = 'cortex_mdt.cctv.admin',
    adminRanks = {
        'Captain',
        'Commander',
        'Assistant Chief',
        'Chief',
        'Under-Sheriff',
        'Sheriff',
        'Commissioner',
        'Director',
        'Manager',
    },
    defaultFov = 52.0,
    minFov = 18.0,
    maxFov = 90.0,
}

-- Live bodycams are framework-independent. On standalone servers every
-- registered on-duty officer is considered recording unless they opt out with
-- /bodycam. Frames are only transmitted while at least one authorised viewer
-- is watching the feed.
Config.Bodycams = {
    enabled = true,
    command = 'bodycam',
    autoActivateOnDuty = true,
    allowCrossRoutingBuckets = false,
    streamIntervalMs = 100,
    staleFrameMs = 2000,
    maxViewersPerFeed = 16,
    audio = {
        enabled = true,
        -- Safe mode: adjusts an already-routed Mumble voice only. It never
        -- replaces pma-voice radio/call targets and cannot hear distant audio.
        mode = 'proximity',
        volume = 1.0,
    },
}

-- Dashcams are derived from on-duty officers driving emergency-class vehicles.
-- Per-model offsets can be added with model names as keys; the default keeps
-- standalone setup zero-config while still allowing vehicle-specific tuning.
Config.Dashcams = {
    enabled = true,
    emergencyVehicleClass = 18,
    syncIntervalMs = 200,
    allowCrossRoutingBuckets = false,
    defaultOffset = { x = 0.0, y = 0.72, z = 1.18 },
    defaultRearOffset = { x = 0.0, y = -0.82, z = 1.12 },
    defaultPitch = -5.0,
    defaultRearPitch = -3.0,
    -- Local-space axes are x = right, y = forward, z = up (metres).
    -- Project Sloth side/forward/height entries are accepted too.
    modelOffsets = {
        -- ['police'] = {
        --     front = { x = 0.0, y = 0.75, z = 0.55, pitch = 1.0 },
        --     rear = { x = 0.0, y = -1.20, z = 0.60, pitch = 1.0 },
        -- },
        -- ['police2'] = { side = 0.0, forward = 1.10, height = 0.85, pitch = -6.0 },
    },
}

-- Cortex PolCam publishes validated camera transforms through server exports.
-- The MDT mirrors those transforms as a read-only feed; operator zoom, vision,
-- target lock, and camera motion stay synchronised for every viewer.
Config.AirSupport = {
    enabled = true,
    resource = 'cortex_polcam',
    syncIntervalMs = 200,
    allowCrossRoutingBuckets = false,
    requireOperatorOnDuty = true,
    requirePilotOnDuty = true,
}

-- Cross-department visibility for the parity modules. Mutual groups share in
-- both directions; one-way entries allow viewers to read target departments.
Config.DepartmentSharing = {
    mutual = {
        {
            departments = { 'police', 'sheriff', 'highway' },
            features = { 'bulletins', 'awards', 'ia', 'ppr', 'court', 'sops', 'patrols' },
        },
    },
    oneWay = {},
}

Config.FeatureParity = {
    enabled = true,
    manageAce = 'cortex_mdt.manage',
    publicComplaintCommand = 'complaint',
    maxRecordsPerFeature = 2000,
    features = {
        bulletins = true,
        awards = true,
        ia = true,
        ppr = true,
        court = true,
        sops = true,
        patrols = true,
    },
}

-- Preset license types seeded into mdt_license_types on first fetch.
-- Admins can add, remove, or toggle these from the Settings UI.
Config.LicenseTypes = {
    {
        id = 'driver',
        label = "Driver's License",
        description = 'Authorizes operation of non-commercial motor vehicles on public roadways. Required for all vehicle classes up to Class C. Subject to vision test and written examination.',
    },
    {
        id = 'commercial_driver',
        label = 'Commercial Driver License (CDL)',
        description = 'Authorizes operation of commercial and heavy vehicles including tractor-trailers, buses, and vehicles carrying hazardous materials. Requires annual medical clearance and specialized endorsements.',
    },
    {
        id = 'motorcycle',
        label = 'Motorcycle Endorsement',
        description = 'Authorizes operation of two-wheeled and three-wheeled motorcycles on all public roadways. Requires completion of a certified motorcycle safety course with practical riding examination.',
    },
    {
        id = 'pilot',
        label = "Pilot's License",
        description = 'Certifies the holder to operate fixed-wing and rotary aircraft within state airspace. Requires logged flight hours, biannual medical fitness examination, and FAA practical test completion.',
    },
    {
        id = 'weapon',
        label = 'Weapon Carry Permit',
        description = 'Authorizes the concealed or open carry of a registered firearm within state limits. Subject to background investigation, mandatory firearm safety training, and periodic renewal with proficiency demonstration.',
    },
    {
        id = 'hunting',
        label = 'Hunting License',
        description = 'Permits the holder to hunt designated game species during regulated seasons using approved methods. Requires completion of a state-certified hunter education and safety course.',
    },
    {
        id = 'fishing',
        label = 'Fishing License',
        description = 'Authorizes recreational and sport fishing in public waterways, lakes, and coastal regions within state jurisdiction. Subject to daily bag limits, size restrictions, and seasonal closures.',
    },
    {
        id = 'business',
        label = 'Business Operating License',
        description = 'Required for any legal commercial entity conducting business within the state. Must display at place of business. Renewed annually with tax compliance verification and zoning approval.',
    },
    {
        id = 'food_vendor',
        label = 'Food Vendor Permit',
        description = 'Certifies the holder to prepare, handle, and sell food products to the public. Requires health department inspection, food safety certification, sanitary facility approval, and annual renewal.',
    },
    {
        id = 'real_estate',
        label = 'Real Estate Agent License',
        description = 'Authorizes the holder to broker, list, and facilitate the sale or lease of residential and commercial property. Requires state board examination, continuing education credits, and agency sponsorship.',
    },
    {
        id = 'medical',
        label = 'Medical Practice License',
        description = 'Authorizes the holder to practice medicine, prescribe treatment, and perform medical procedures within state jurisdiction. Requires accredited degree, residency completion, board certification, and DEA registration.',
    },
    {
        id = 'security',
        label = 'Security Guard Card',
        description = 'Certifies the holder to work as a licensed private security officer. Requires criminal background check, fingerprint clearance, and completion of state-mandated guard training with annual renewal.',
    },
    {
        id = 'liquor',
        label = 'Liquor License',
        description = 'Authorizes the sale, service, and distribution of alcoholic beverages at an approved establishment. Subject to zoning restrictions, state alcohol control board regulations, and public hearing process.',
    },
    {
        id = 'firearms_dealer',
        label = 'Federal Firearms License (FFL)',
        description = 'Authorizes the holder to engage in the business of manufacturing, importing, or dealing firearms and ammunition. Requires ATF compliance, thorough background investigation, and premises inspection.',
    },
    {
        id = 'legal',
        label = 'Legal Practice License',
        description = 'Authorizes the holder to practice law, represent clients in court, and provide legal counsel within state jurisdiction. Requires law degree, bar examination passage, and good standing with the state bar association.',
    },
}

-- Citation system. Officers can issue paper citations from report detail view
-- and civilians can view them via /showcitation command or inventory item.
Config.Citations = {
    enabled = true,

    -- When true, issued citations are persisted to data/localStorage.json
    -- (local mode) or MySQL (database mode). When false, citations are session-only.
    persist = true,

    -- Inventory item name for framework mode (e.g. QBCore/ESX shared item).
    -- Set to false to disable inventory item. Set to a string ('citation') to enable.
    inventoryItem = 'citation',

    -- /showcitation command for standalone/ERS mode
    showCommand = 'showcitation',

    -- Notification when a citation is issued
    enableNotification = true,
}

-- Static camera prop models (aligned with Project Sloth ps-mdt model set)
Config.CameraModels = {
    ['security_cam_01'] = 'v_serv_securitycam_1a',
    ['security_cam_02'] = 'v_serv_securitycam_03',
    ['security_cam_03'] = 'ba_prop_battle_cctv_cam_01a',
    ['security_cam_04'] = 'prop_cctv_cam_06a',
    ['security_cam_05'] = 'ba_prop_battle_cctv_cam_01b',
    ['security_cam_06'] = 'prop_cctv_cam_01b',
    ['security_cam_07'] = 'ch_prop_ch_cctv_cam_02a',
    ['security_cam_08'] = 'prop_cctv_cam_04c',
    ['security_cam_09'] = 'prop_cctv_cam_03a',
    ['security_cam_10'] = 'ch_prop_ch_cctv_cam_01a',
    ['security_cam_11'] = 'prop_cctv_cam_01a',
    ['security_cam_12'] = 'prop_cctv_cam_05a',
    ['security_cam_13'] = 'prop_cctv_cam_07a',
    ['security_cam_14'] = 'prop_cctv_cam_04b',
    ['security_cam_15'] = 'tr_prop_tr_camhedz_cctv_01a',
    ['security_cam_16'] = 'prop_cctv_cam_02a',
    ['security_cam_17'] = 'prop_cctv_cam_04a',
    ['cctv_cam_01'] = 'm24_1_prop_m24_1_carrier_bank_cctv_02',
    ['cctv_cam_02'] = 'xm_prop_x17_cctv_01a',
    ['cctv_cam_03'] = 'prop_cctv_pole_02',
    ['cctv_cam_04'] = 'm24_1_prop_m24_1_carrier_bank_cctv_01',
    ['cctv_cam_05'] = 'prop_cctv_pole_04',
    ['cctv_cam_06'] = 'xm_prop_x17_server_farm_cctv_01',
}
