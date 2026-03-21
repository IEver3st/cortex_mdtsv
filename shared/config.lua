-- Cortex MDT Configuration
Config = {}

-- Active framework mode.
-- Supported values: 'auto', 'standalone', 'qbx', 'ers'
Config.FrameworkMode = 'standalone'

-- Auto-detect priority used when FrameworkMode = 'auto'
Config.FrameworkAutoDetectPriority = { 'ers', 'qbx', 'standalone' }

-- Backwards-compatible alias.
Config.Framework = Config.FrameworkMode

-- Command to open the MDT
Config.OpenCommand = 'mdt'

-- Keybind to open the MDT (https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/)
Config.OpenKey = 'F11'

-- Resource names used by the auto-detector.
Config.FrameworkResources = {
    qbx = 'qbx_core',
    ers = 'night_ers',
    ersFallbacks = {
        'EmergencyResponseSimulator',
        'ers',
    },
}

Config.StandaloneCivilianMode = {
    enabled = true,
    citizenPrefix = 'STN',
    maxCitizensPerSession = 64,
    claimOnGenerate = true,
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
