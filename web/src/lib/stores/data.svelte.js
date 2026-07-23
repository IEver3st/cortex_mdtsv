import { nuiPost, isEnvBrowser } from '../utils/nui.js';
import { playMdtSound } from '../utils/mdtSounds.js';
import { mdtStore } from './mdt.svelte.js';
import { normalizeUnitStatus } from '../utils/helpers.js';
import { DEFAULT_CHARGES, applyChargePatch, normalizeChargesList } from '../data/charges.js';

const DEFAULT_MUGSHOT_URL = 'https://st2.depositphotos.com/2101611/6967/v/450/depositphotos_69670367-stock-illustration-picture-of-anonymous-male-silhouette.jpg';

function withDefaultMugshot(row) {
  if (!row || typeof row !== 'object') return row;
  const mugshot = String(row.mugshot || row.mugshotUrl || row.mugshot_url || row.photoUrl || row.photo_url || '').trim() || DEFAULT_MUGSHOT_URL;
  return {
    ...row,
    mugshot,
    mugshotUrl: row.mugshotUrl || mugshot,
  };
}

function createDataStore() {
  let standaloneCitizens = $state([]);
  let standaloneVehicles = $state([]);
  let standaloneCivilianState = $state({
    activeCitizenId: null,
    standaloneEnabled: false,
    maxCitizensPerSession: 0,
    frameworkMode: 'standalone',
    error: null,
  });

  let dashboardStats = $state({ activeCalls: 0, openReports: 0, activeWarrants: 0, unitsOnDuty: 0 });
  let dashboardMotd = $state('');
  let dashboardBolos = $state([]);
  let dashboardAnnouncements = $state([]);
  let dashboardDispatchCalls = $state([]);
  let dashboardRecentReports = $state([]);
  let dashboardOnDutyOfficers = $state([]);
  let dashboardChatMessages = $state([]);
  let chatInput = $state('');

  let citizenSearchResults = $state([]);
  let selectedCitizen = $state(null);
  let citizenVehicles = $state([]);
  let citizenLicenses = $state([]);
  let citizenReports = $state([]);
  let citizenWarrants = $state([]);
  let citizenBolos = $state([]);

  // ─── Citizen Session Cache ───
  let citizenSessionCache = $state(new Map());
  let recentCitizens = $state([]);

  let weaponsList = $state([]);
  let selectedWeapon = $state(null);
  let weaponHistory = $state([]);
  let weaponAnalytics = $state({
    total: 0,
    registered: 0,
    transferred: 0,
    seized: 0,
    evidence: 0,
    stolen: 0,
    destroyed: 0,
    recentTransfers: 0,
  });

  let vehicleSearchResults = $state([]);
  let selectedVehicle = $state(null);
  let vehicleImpounds = $state([]);
  let recentVehicles = $state([]);

  let reportsList = $state([]);
  let reportsTotal = $state(0);
  let selectedReport = $state(null);
  let reportTimeline = $state([]);
  let reportEntities = $state([]);
  let reportParticipants = $state([]);
  let reportCharges = $state([]);
  let reportAttachments = $state([]);
  let reportCollaborators = $state([]);

  let casesList = $state([]);
  let casesTotal = $state(0);
  let selectedCase = $state(null);
  let casePersonnel = $state([]);
  let caseLinks = $state([]);
  let caseAttachments = $state([]);

  let evidenceList = $state([]);
  let evidenceTotal = $state(0);
  let selectedEvidence = $state(null);
  let evidenceCustody = $state([]);
  let evidenceAttachments = $state([]);

  let bolosList = $state([]);

  let warrantsList = $state([]);

  let unitsList = $state([]);
  let leaderboardData = $state({
    summary: {
      totalOfficers: 0,
      totalReports: 0,
      totalArrests: 0,
      averageActivity: 0,
    },
    categories: {
      arrests: [],
      reports: [],
      activity: [],
    },
    generatedAt: null,
    period: 'week',
  });

  let cctvCameras = $state([]);
  let cameraModels = $state([]);
  let cctvCanManage = $state(false);
  let activeCameraFeed = $state(null);

  let bodycamsList = $state([]);
  let activeBodycamFeed = $state(null);
  /** Live street line from client while viewing bodycam (target ped position). */
  let bodycamLiveLocation = $state('');

  let chargesList = $state([]);
  let licenseTypesList = $state([]);

  let dispatchCalls = $state([]);
  let dispatchActiveUnits = $state([]);
  let selectedDispatchId = $state(null);
  let dispatchActionState = $state({ busy: false, error: '' });
  let dispatchNoteDraft = $state('');
  let dispatchCloseReason = $state('');

  let adminRoster = $state([]);
  let adminAuditLogs = $state([]);
  let adminSettings = $state({});

  let globalSearchResults = $state({});

  let configData = $state(null);

  let officerResults = $state([]);

  function applyStandaloneCivilianState(payload) {
    if (!payload) {
      return;
    }

    standaloneCitizens = (payload.citizens || []).map(withDefaultMugshot);
    standaloneVehicles = payload.vehicles || [];
    standaloneCivilianState = {
      activeCitizenId: payload.activeCitizenId || null,
      standaloneEnabled: payload.standaloneEnabled === true,
      maxCitizensPerSession: payload.maxCitizensPerSession || 0,
      frameworkMode: payload.frameworkMode || 'standalone',
      error: payload.error || null,
    };

    if (payload.civilian) {
      mdtStore.civilian = withDefaultMugshot(payload.civilian);
    }
  }

  function normalizeWeapon(row = {}) {
    const weaponName = row.weapon_name || row.weaponName || row.weapon_type || row.weaponType || row.model || row.make || '';
    const weaponClass = row.weapon_class || row.weaponClass || row.caliber || row.weapon_type || row.weaponType || '';
    const photoUrl = row.photo_url || row.photoUrl || row.image_url || row.imageUrl || '';

    return {
      ...row,
      weapon_name: weaponName,
      weaponName,
      weapon_type: row.weapon_type || row.weaponType || weaponName,
      weaponType: row.weaponType || row.weapon_type || weaponName,
      weapon_class: weaponClass,
      weaponClass,
      make: row.make || '',
      model: row.model || weaponName,
      caliber: row.caliber || weaponClass,
      photo_url: photoUrl,
      photoUrl,
      image_url: row.image_url || row.imageUrl || photoUrl,
      imageUrl: row.imageUrl || row.image_url || photoUrl,
    };
  }

  function loadBrowserStandaloneState() {
    const mockCitizens = [
      {
        id: 'STN-0001',
        citizenId: 'STN-0001',
        citizen_id: 'STN-0001',
        firstName: 'Avery',
        first_name: 'Avery',
        lastName: 'Harper',
        last_name: 'Harper',
        fullName: 'Avery Harper',
        dateOfBirth: '1996-07-14',
        dob: '1996-07-14',
        gender: 'Non-binary',
        phone: '555-214-7841',
        address: '412 Alta St, Los Santos',
        occupation: 'Courier',
        nationality: 'San Andreas',
        email: 'avery.harper@lsmail.com',
        height: "5'08\"",
        eyeColor: 'Hazel',
        bloodType: 'O+',
        emergencyContact: 'Taylor Harper (555-311-9192)',
        standalone: true,
        generated: true,
        claimed: true,
        isOwner: true,
        isActive: true,
        vehicleCount: 1,
        citationCount: 0,
        warrantCount: 0,
        recordCount: 0,
      },
      {
        id: 'STN-0002',
        citizenId: 'STN-0002',
        citizen_id: 'STN-0002',
        firstName: 'Rowan',
        first_name: 'Rowan',
        lastName: 'Diaz',
        last_name: 'Diaz',
        fullName: 'Rowan Diaz',
        dateOfBirth: '1991-02-03',
        dob: '1991-02-03',
        gender: 'Male',
        phone: '555-115-4022',
        address: '198 Mirror Park Blvd, Los Santos',
        occupation: 'Mechanic',
        nationality: 'United States',
        email: 'rowan.diaz@citylink.sa',
        height: "6'00\"",
        eyeColor: 'Brown',
        bloodType: 'A+',
        emergencyContact: 'Casey Diaz (555-981-1100)',
        standalone: true,
        generated: true,
        claimed: false,
        isOwner: false,
        isActive: false,
        vehicleCount: 0,
        citationCount: 0,
        warrantCount: 0,
        recordCount: 0,
      },
    ];

    const mockVehicles = [
      {
        id: 'standalone:STNV-0001',
        vehicleId: 'STNV-0001',
        vehicle_id: 'STNV-0001',
        plate: 'AVR 214',
        model: 'Vapid Dominator',
        color: 'Matte Black',
        vehicleClass: 'Muscle',
        vehicle_class: 'Muscle',
        registrationStatus: 'valid',
        registration_status: 'valid',
        insurance: 'Active',
        regExpiry: '2027-06-14',
        year: '2024',
        ownerCitizenId: 'STN-0001',
        owner_citizen_id: 'STN-0001',
        ownerName: 'Avery Harper',
        owner_name: 'Avery Harper',
        flags: [],
        standalone: true,
      },
    ];

    standaloneCitizens = mockCitizens;
    standaloneVehicles = mockVehicles;
    standaloneCivilianState = {
      activeCitizenId: 'STN-0001',
      standaloneEnabled: true,
      maxCitizensPerSession: 8,
      frameworkMode: 'standalone',
      error: null,
    };
    mdtStore.civilian = mockCitizens[0];

    return {
      ok: true,
      citizens: mockCitizens,
      vehicles: mockVehicles,
      civilian: mockCitizens[0],
      ...standaloneCivilianState,
    };
  }

  function buildBrowserFallbackCivilian() {
    return {
      firstName: 'Citizen',
      lastName: '',
      citizenId: null,
      vehicleCount: 0,
      citationCount: 0,
      warrantCount: 0,
      recordCount: 0,
      standalone: true,
      generated: false,
      claimed: false,
      hasActiveCitizen: false,
    };
  }

  function updateBrowserActiveCitizen(citizenId = null) {
    standaloneCitizens = standaloneCitizens.map((citizen) => ({
      ...citizen,
      claimed: citizen.citizenId === citizenId,
      isOwner: citizen.citizenId === citizenId,
      isActive: citizen.citizenId === citizenId,
    }));

    standaloneCivilianState = {
      ...standaloneCivilianState,
      activeCitizenId: citizenId,
    };

    const activeCitizen = standaloneCitizens.find((citizen) => citizen.citizenId === citizenId) || null;
    const vehicleCount = activeCitizen ? standaloneVehicles.filter((vehicle) => vehicle.owner_citizen_id === activeCitizen.citizenId).length : 0;

    if (activeCitizen) {
      mdtStore.civilian = { ...activeCitizen, vehicleCount };
    } else {
      mdtStore.civilian = buildBrowserFallbackCivilian();
    }
  }

  function syncBrowserVehicleCounts() {
    standaloneCitizens = standaloneCitizens.map((citizen) => ({
      ...citizen,
      vehicleCount: standaloneVehicles.filter((vehicle) => vehicle.owner_citizen_id === citizen.citizenId).length,
    }));

    const activeCitizen = standaloneCitizens.find((citizen) => citizen.isActive) || null;
    if (activeCitizen) {
      mdtStore.civilian = activeCitizen;
    }
  }

  async function fetchStandaloneCivilianState() {
    if (isEnvBrowser()) {
      return loadBrowserStandaloneState();
    }

    const resp = await nuiPost('cortex_mdt:getStandaloneCivilianState');
    if (resp?.ok) {
      applyStandaloneCivilianState(resp);
    } else if (resp) {
      standaloneCivilianState = {
        ...standaloneCivilianState,
        standaloneEnabled: resp.standaloneEnabled === true,
        frameworkMode: resp.frameworkMode || standaloneCivilianState.frameworkMode,
        error: resp.error || 'Unable to load standalone civilians.',
      };
    } else {
      // resp is null — fetch failed entirely (no NUI callback, network error, etc.)
      // Default to enabled so the UI doesn't show "STANDALONE DISABLED" incorrectly
      standaloneCivilianState = {
        ...standaloneCivilianState,
        standaloneEnabled: true,
        error: 'Could not communicate with the server. Standalone mode assumed.',
      };
    }

    return resp;
  }

  async function generateStandaloneCivilian(payload = {}) {
    if (isEnvBrowser()) {
      const nextIndex = standaloneCitizens.length + 1;
      const citizen = {
        id: `STN-${String(nextIndex).padStart(4, '0')}`,
        citizenId: `STN-${String(nextIndex).padStart(4, '0')}`,
        citizen_id: `STN-${String(nextIndex).padStart(4, '0')}`,
        firstName: 'Generated',
        first_name: 'Generated',
        lastName: `Citizen ${nextIndex}`,
        last_name: `Citizen ${nextIndex}`,
        fullName: `Generated Citizen ${nextIndex}`,
        dateOfBirth: '1994-09-18',
        dob: '1994-09-18',
        gender: 'Female',
        phone: '555-201-9901',
        address: '522 Hawick Ave, Los Santos',
        occupation: 'Dispatcher',
        nationality: 'San Andreas',
        email: `generated.${nextIndex}@lsmail.com`,
        height: "5'07\"",
        eyeColor: 'Green',
        bloodType: 'B+',
        emergencyContact: 'Jordan Reed (555-221-8842)',
        standalone: true,
        generated: true,
        claimed: false,
        isOwner: false,
        isActive: false,
        vehicleCount: 0,
        citationCount: 0,
        warrantCount: 0,
        recordCount: 0,
      };

      standaloneCitizens = [citizen, ...standaloneCitizens];
      updateBrowserActiveCitizen(citizen.citizenId);
      return {
        ok: true,
        citizen,
        citizens: standaloneCitizens,
        vehicles: standaloneVehicles,
        civilian: mdtStore.civilian,
        ...standaloneCivilianState,
      };
    }

    const resp = await nuiPost('cortex_mdt:generateStandaloneCivilian', payload);
    if (resp?.ok) {
      applyStandaloneCivilianState(resp);
    }
    return resp;
  }

  async function registerStandaloneCivilian(payload = {}) {
    if (isEnvBrowser()) {
      const nextIndex = standaloneCitizens.length + 1;
      const citizenId = `STN-${String(nextIndex).padStart(4, '0')}`;
      const flags = {};
      if (payload.hasWarrant) flags['wanted'] = true;
      if (payload.hasSpeedingPrior) flags['speeding_prior'] = true;

      const citizen = {
        id: citizenId,
        citizenId: citizenId,
        citizen_id: citizenId,
        firstName: payload.firstName || 'Unknown',
        first_name: payload.firstName || 'Unknown',
        lastName: payload.lastName || 'Citizen',
        last_name: payload.lastName || 'Citizen',
        fullName: `${payload.firstName || 'Unknown'} ${payload.lastName || 'Citizen'}`,
        dateOfBirth: payload.dob || '1990-01-01',
        dob: payload.dob || '1990-01-01',
        gender: 'Unspecified',
        phone: payload.phone || '555-000-0000',
        address: 'Los Santos',
        occupation: 'Unemployed',
        nationality: payload.nationality || 'San Andreas',
        email: `${(payload.firstName || 'unknown').toLowerCase()}.${(payload.lastName || 'citizen').toLowerCase()}@lsmail.com`,
        height: "5'08\"",
        eyeColor: 'Brown',
        bloodType: 'O+',
        emergencyContact: 'N/A',
        mugshot: payload.mugshot || DEFAULT_MUGSHOT_URL,
        flags: flags,
        notes: payload.notes ? `[Self-Registered]: ${payload.notes}` : null,
        standalone: true,
        generated: false,
        claimed: true,
        isOwner: true,
        isActive: true,
        vehicleCount: 0,
        citationCount: payload.hasSpeedingPrior ? 1 : 0,
        warrantCount: payload.hasWarrant ? 1 : 0,
        recordCount: payload.notes ? 1 : 0,
      };

      standaloneCitizens = [withDefaultMugshot(citizen), ...standaloneCitizens];
      updateBrowserActiveCitizen(citizenId);
      return {
        ok: true,
        citizen,
        citizens: standaloneCitizens,
        vehicles: standaloneVehicles,
        civilian: mdtStore.civilian,
        ...standaloneCivilianState,
      };
    }

    const resp = await nuiPost('cortex_mdt:registerStandaloneCivilian', payload);
    if (resp?.ok) {
      applyStandaloneCivilianState(resp);
    }
    return resp;
  }

  async function claimStandaloneCivilian(citizenId) {
    if (isEnvBrowser()) {
      const activeCitizen = standaloneCitizens.find((citizen) => citizen.citizenId === citizenId) || null;
      updateBrowserActiveCitizen(citizenId);
      return {
        ok: true,
        citizen: activeCitizen ? { ...activeCitizen, claimed: true, isOwner: true, isActive: true } : null,
        civilians: standaloneCitizens,
        citizens: standaloneCitizens,
        vehicles: standaloneVehicles.filter((vehicle) => vehicle.owner_citizen_id === citizenId),
        civilian: mdtStore.civilian,
        ...standaloneCivilianState,
      };
    }

    const resp = await nuiPost('cortex_mdt:claimStandaloneCivilian', { citizenId });
    if (resp?.ok) {
      applyStandaloneCivilianState(resp);
    }
    return resp;
  }

  async function unclaimStandaloneCivilian(citizenId) {
    if (isEnvBrowser()) {
      const citizen = standaloneCitizens.find((entry) => entry.citizenId === citizenId) || null;
      if (!citizen) {
        return { ok: false, error: 'Civilian not found.' };
      }

      updateBrowserActiveCitizen(null);

      return {
        ok: true,
        citizen: { ...citizen, claimed: false, isOwner: false, isActive: false },
        citizens: standaloneCitizens,
        vehicles: [],
        civilian: mdtStore.civilian,
        ...standaloneCivilianState,
      };
    }

    const resp = await nuiPost('cortex_mdt:unclaimStandaloneCivilian', { citizenId });
    if (resp?.ok) {
      applyStandaloneCivilianState(resp);
    }
    return resp;
  }

  async function deleteStandaloneCivilian(citizenId) {
    if (isEnvBrowser()) {
      standaloneCitizens = standaloneCitizens.filter((citizen) => citizen.citizenId !== citizenId);
      standaloneVehicles = standaloneVehicles.map((vehicle) => (
        vehicle.owner_citizen_id === citizenId
          ? { ...vehicle, owner_citizen_id: null, ownerCitizenId: null, owner_name: 'Unassigned', ownerName: 'Unassigned' }
          : vehicle
      ));
      syncBrowserVehicleCounts();
      const nextActiveCitizen = standaloneCitizens.find((citizen) => citizen.claimed) || null;
      standaloneCivilianState = {
        ...standaloneCivilianState,
        activeCitizenId: nextActiveCitizen?.citizenId || null,
      };
      if (nextActiveCitizen) {
        mdtStore.civilian = nextActiveCitizen;
      } else {
        mdtStore.civilian = buildBrowserFallbackCivilian();
      }
      return {
        ok: true,
        citizens: standaloneCitizens,
        vehicles: nextActiveCitizen ? standaloneVehicles.filter((vehicle) => vehicle.owner_citizen_id === nextActiveCitizen.citizenId) : [],
        civilian: nextActiveCitizen,
        ...standaloneCivilianState,
      };
    }

    const resp = await nuiPost('cortex_mdt:deleteStandaloneCivilian', { citizenId });
    if (resp?.ok) {
      applyStandaloneCivilianState(resp);
    }
    return resp;
  }

  async function registerStandaloneVehicle(payload = {}) {
    if (isEnvBrowser()) {
      const activeCitizenId = standaloneCivilianState.activeCitizenId;
      if (!activeCitizenId) {
        return { ok: false, error: 'Claim a civilian before registering a vehicle.' };
      }

      const activeCitizen = standaloneCitizens.find((citizen) => citizen.citizenId === activeCitizenId) || null;
      if (!activeCitizen) {
        return { ok: false, error: 'Active civilian not found.' };
      }

      const plate = String(payload.plate || '').trim().toUpperCase();
      if (!plate) {
        return { ok: false, error: 'Vehicle plate is required.' };
      }

      const existing = standaloneVehicles.find((vehicle) => vehicle.plate === plate);
      const vehicle = {
        id: existing?.id || `standalone:STNV-${String(standaloneVehicles.length + 1).padStart(4, '0')}`,
        vehicleId: existing?.vehicleId || `STNV-${String(standaloneVehicles.length + 1).padStart(4, '0')}`,
        vehicle_id: existing?.vehicle_id || `STNV-${String(standaloneVehicles.length + 1).padStart(4, '0')}`,
        plate,
        model: payload.model || existing?.model || 'Unknown Vehicle',
        color: payload.color || existing?.color || 'Unspecified',
        vehicleClass: payload.vehicleClass || existing?.vehicleClass || 'Passenger',
        vehicle_class: payload.vehicleClass || existing?.vehicle_class || 'Passenger',
        registrationStatus: payload.registrationStatus || existing?.registrationStatus || 'valid',
        registration_status: payload.registrationStatus || existing?.registration_status || 'valid',
        insurance: existing?.insurance || 'Active',
        regExpiry: existing?.regExpiry || '2027-01-01',
        year: payload.year || existing?.year || '2024',
        ownerCitizenId: activeCitizen.citizenId,
        owner_citizen_id: activeCitizen.citizenId,
        ownerName: activeCitizen.fullName,
        owner_name: activeCitizen.fullName,
        flags: existing?.flags || [],
        standalone: true,
      };

      standaloneVehicles = existing
        ? standaloneVehicles.map((entry) => (entry.id === existing.id ? vehicle : entry))
        : [vehicle, ...standaloneVehicles];

      syncBrowserVehicleCounts();

      return {
        ok: true,
        vehicle,
        citizens: standaloneCitizens,
        vehicles: standaloneVehicles.filter((entry) => entry.owner_citizen_id === activeCitizen.citizenId),
        civilian: mdtStore.civilian,
        ...standaloneCivilianState,
      };
    }

    const resp = await nuiPost('cortex_mdt:registerStandaloneVehicle', payload);
    if (resp?.ok) {
      applyStandaloneCivilianState(resp);
    }
    return resp;
  }

  async function registerCurrentStandaloneVehicle(payload = {}) {
    if (isEnvBrowser()) {
      return registerStandaloneVehicle({
        plate: 'CURR 001',
        model: 'Karin Sultan RS',
        vehicleClass: 'Sports',
        color: 'Midnight Blue',
        ...payload,
      });
    }

    const resp = await nuiPost('cortex_mdt:registerCurrentStandaloneVehicle', payload);
    if (resp?.ok) {
      applyStandaloneCivilianState(resp);
    }
    return resp;
  }

  async function fetchDashboard() {
    if (isEnvBrowser()) {
      dashboardStats = { activeCalls: 3, openReports: 7, activeWarrants: 2, unitsOnDuty: 5 };
      dashboardMotd = 'All units, be advised: increased patrol presence requested in Strawberry and Davis. Stay safe out there.';
      dashboardBolos = [
        { id: 1, type: 'vehicle', title: 'Black Bravado Buffalo — Plates: 8KAP224', created_at: new Date(Date.now() - 18 * 60000).toISOString() },
        { id: 2, type: 'person', title: 'Male suspect, red hoodie, armed — Grove St area', created_at: new Date(Date.now() - 42 * 60000).toISOString() },
        { id: 3, type: 'vehicle', title: 'White Karin Sultan RS — Plates: Unknown, no front plate', created_at: new Date(Date.now() - 95 * 60000).toISOString() },
        { id: 4, type: 'weapon', title: 'Reported illegal firearm trafficking near LS docks', created_at: new Date(Date.now() - 180 * 60000).toISOString() },
      ];
      dashboardAnnouncements = [
        { id: 1, title: 'New SOP Update', content: 'Updated use-of-force guidelines are now in effect. All officers must review the new policy by end of shift.' },
        { id: 2, title: 'Scheduled Maintenance', content: 'MDT servers will undergo maintenance Saturday 03:00–05:00. Plan accordingly.' },
      ];
      dashboardDispatchCalls = [
        { id: 'CAD-1042', code: '10-42', type: '10-42', description: 'Traffic stop — Vespucci Blvd & Eclipse', unit: '1-A-15', location: 'Vespucci Blvd', status: 'active', created_at: new Date(Date.now() - 4 * 60000).toISOString() },
        { id: 'CAD-1031', code: '10-31', type: '10-31', description: 'Shots fired — Grove Street', unit: '1-X-01', location: 'Grove St', status: 'active', created_at: new Date(Date.now() - 11 * 60000).toISOString() },
        { id: 'CAD-1015', code: '10-15', type: '10-15', description: 'Suspect in custody, en route to MRPD', unit: '1-A-22', location: 'MRPD', status: 'in_progress', created_at: new Date(Date.now() - 22 * 60000).toISOString() },
        { id: 'CAD-1097', code: '10-97', type: '10-97', description: 'On scene — Welfare check Sandy Shores', unit: '2-S-07', location: 'Sandy Shores', status: 'in_progress', created_at: new Date(Date.now() - 35 * 60000).toISOString() },
      ];
      dashboardRecentReports = [
        { id: 'RPT-00240321-0012', title: 'Pursuit — Vespucci Blvd to LSIA', author: 'Sgt. Sarah Chen', status: 'open', created_at: new Date(Date.now() - 28 * 60000).toISOString() },
        { id: 'RPT-00240321-0011', title: 'Arrest Report — Possession w/ Intent', author: 'Ofc. Marcus Rivera', status: 'pending_review', created_at: new Date(Date.now() - 75 * 60000).toISOString() },
        { id: 'RPT-00240321-0009', title: 'Use of Force — Suspect Resisted Arrest', author: 'Cpl. Alex Kim', status: 'approved', created_at: new Date(Date.now() - 142 * 60000).toISOString() },
        { id: 'RPT-00240321-0008', title: 'Traffic Incident — Route 68 Collision', author: 'Ofc. Diana Vasquez', status: 'open', created_at: new Date(Date.now() - 230 * 60000).toISOString() },
      ];
      dashboardOnDutyOfficers = [
        { id: 1, callsign: '1-A-12', name: 'John Doe', rank: 'Officer', status: 'available', department: 'LSPD', avatar: '' },
        { id: 2, callsign: '1-A-15', name: 'Sarah Chen', rank: 'Sergeant', status: 'en_route', department: 'LSPD', avatar: '' },
        { id: 3, callsign: '1-L-20', name: 'Marcus Rivera', rank: 'Officer', status: 'on_scene', department: 'LSPD', avatar: '' },
        { id: 4, callsign: '1-X-01', name: 'Alex Kim', rank: 'Corporal', status: 'emergency', department: 'LSPD', avatar: '' },
        { id: 5, callsign: '1-A-22', name: 'Diana Vasquez', rank: 'Officer', status: 'busy', department: 'LSPD', avatar: '' },
        { id: 6, callsign: '2-S-01', name: 'James Harper', rank: 'Deputy', status: 'available', department: 'BCSO', avatar: '' },
        { id: 7, callsign: '2-S-07', name: 'Mia Torres', rank: 'Sr. Deputy', status: 'on_scene', department: 'BCSO', avatar: '' },
      ];
      dashboardChatMessages = [
        { id: 1, callsign: '1-A-15', name: 'Chen', rank: 'Sgt.', message: 'All units use caution on Grove St, multiple armed suspects.', timestamp: new Date(Date.now() - 5 * 60000).toISOString() },
        { id: 2, callsign: '1-X-01', name: 'Kim', rank: 'Cpl.', message: 'Copy. Requesting backup at Grove & Forum, 10-31 in progress.', timestamp: new Date(Date.now() - 4 * 60000).toISOString() },
        { id: 3, callsign: '1-A-22', name: 'Vasquez', rank: 'Ofc.', message: 'En route to backup. ETA 2 minutes.', timestamp: new Date(Date.now() - 3 * 60000).toISOString() },
        { id: 4, callsign: '2-S-01', name: 'Harper', rank: 'Dep.', message: 'BCSO available for mutual aid if needed.', timestamp: new Date(Date.now() - 90000).toISOString() },
      ];
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getDashboard');
    if (resp?.ok) {
      dashboardStats = resp.stats;
      dashboardMotd = resp.motd;
      dashboardBolos = resp.bolos;
      dashboardAnnouncements = resp.announcements;
      dashboardDispatchCalls = resp.dispatchCalls || [];
      dashboardRecentReports = resp.recentReports || [];
      dashboardOnDutyOfficers = resp.onDutyOfficers || [];
      dashboardChatMessages = resp.chatMessages || [];
    }
    return resp;
  }

  async function refreshDutyStateViews() {
    const [unitsResp, dashboardResp, dispatchResp] = await Promise.all([
      fetchUnits(),
      fetchDashboard(),
      fetchDispatch(),
    ]);

    return {
      ok: unitsResp?.ok === true && dashboardResp?.ok === true && dispatchResp?.ok === true,
      units: unitsResp,
      dashboard: dashboardResp,
      dispatch: dispatchResp,
    };
  }

  async function sendChatMessage(message) {
    if (isEnvBrowser()) {
      const officer = mdtStore.officer;
      const avatarUrl = officer.avatar || mdtStore.settings?.avatarUrl || null;
      const newMsg = {
        id: Date.now(),
        officerId: officer.officerId,
        callsign: officer.callsign,
        name: officer.lastName,
        rank: officer.rank ? officer.rank.substring(0, 4) + '.' : 'Ofc.',
        message,
        timestamp: new Date().toISOString(),
        avatar: avatarUrl || undefined,
        isMine: true,
      };
      dashboardChatMessages = [...dashboardChatMessages, newMsg];
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:sendDashboardChat', { message });
    if (resp?.ok && resp.message) {
      dashboardChatMessages = [...dashboardChatMessages, resp.message];
    }
    return resp;
  }

  const MOCK_CITIZENS = [
    { citizen_id: 'CIT-20260102-1842', first_name: 'Jordan', last_name: 'Mercer', dob: '1992-03-14', gender: 'Male', phone: '555-0142', occupation: 'Mechanic', mugshot: '', flags: ['violent', 'felon'], tags: ['Repeat Offender'], notes: 'Known associate of Southside crew.', arrest_count: 4, property_count: 1, stats: { vehicleCount: 2, reportCount: 6, arrestCount: 4 } },
    { citizen_id: 'CIT-20260115-3021', first_name: 'Samantha', last_name: 'Rivera', dob: '1988-07-22', gender: 'Female', phone: '555-0287', occupation: 'Nurse', mugshot: '', flags: ['medical_alert'], tags: [], notes: '', arrest_count: 0, property_count: 2, stats: { vehicleCount: 1, reportCount: 1, arrestCount: 0 } },
    { citizen_id: 'CIT-20260201-5590', first_name: 'Marcus', last_name: 'Chen', dob: '1995-11-30', gender: 'Male', phone: '555-0391', occupation: 'IT Consultant', mugshot: '', flags: [], tags: ['Cooperating Witness'], notes: 'Provided testimony in Case #447.', arrest_count: 1, property_count: 0, stats: { vehicleCount: 3, reportCount: 2, arrestCount: 1 } },
    { citizen_id: 'CIT-20260210-7744', first_name: 'Elena', last_name: 'Volkov', dob: '1990-01-05', gender: 'Female', phone: '555-0518', occupation: 'Attorney', mugshot: '', flags: ['gang_affiliated'], tags: ['Legal Counsel'], notes: 'Attorney for several persons of interest.', arrest_count: 0, property_count: 3, stats: { vehicleCount: 2, reportCount: 0, arrestCount: 0 } },
    { citizen_id: 'CIT-20260218-9102', first_name: 'Derek', last_name: 'Washington', dob: '1985-06-18', gender: 'Male', phone: '555-0644', occupation: 'Unemployed', mugshot: '', flags: ['active_warrant', 'known_armed', 'violent'], tags: ['High Priority'], notes: 'Warrant: Aggravated assault. Considered dangerous.', arrest_count: 7, property_count: 0, stats: { vehicleCount: 0, reportCount: 12, arrestCount: 7 } },
    { citizen_id: 'CIT-20260305-1337', first_name: 'Natalie', last_name: 'Park', dob: '1997-09-12', gender: 'Female', phone: '555-0773', occupation: 'Student', mugshot: '', flags: ['missing_person'], tags: [], notes: 'Reported missing 2026-03-01. Last seen downtown.', arrest_count: 0, property_count: 0, stats: { vehicleCount: 1, reportCount: 3, arrestCount: 0 } },
  ].map(withDefaultMugshot);

  const MOCK_CITIZEN_VEHICLES = [
    { id: 1, plate: 'MRCER01', model: 'Sultan RS', color: 'Matte Black', status: 'registered', owner_citizen_id: 'CIT-20260102-1842' },
    { id: 2, plate: 'RVRN88', model: 'Futo GTX', color: 'Pearl White', status: 'registered', owner_citizen_id: 'CIT-20260115-3021' },
    { id: 3, plate: 'CHEN33', model: 'Elegy RH8', color: 'Metallic Blue', status: 'registered', owner_citizen_id: 'CIT-20260201-5590' },
    { id: 4, plate: 'VLKV02', model: 'Schafter V12', color: 'Wine Red', status: 'registered', owner_citizen_id: 'CIT-20260210-7744' },
  ];

  const MOCK_CITIZEN_LICENSES = [
    { id: 1, type: 'Driver', status: 'valid', expires_at: '2027-03-14', citizen_id: 'CIT-20260102-1842' },
    { id: 2, type: 'Weapon', status: 'revoked', expires_at: '2026-01-01', citizen_id: 'CIT-20260102-1842' },
    { id: 3, type: 'Driver', status: 'valid', expires_at: '2027-07-22', citizen_id: 'CIT-20260115-3021' },
    { id: 4, type: 'Driver', status: 'valid', expires_at: '2027-11-30', citizen_id: 'CIT-20260201-5590' },
    { id: 5, type: 'Pilot', status: 'valid', expires_at: '2027-11-30', citizen_id: 'CIT-20260201-5590' },
  ];

  async function searchCitizens(query) {
    if (isEnvBrowser()) {
      const q = query.toLowerCase();
      const matches = MOCK_CITIZENS.filter(c =>
        c.first_name.toLowerCase().includes(q) ||
        c.last_name.toLowerCase().includes(q) ||
        c.citizen_id.toLowerCase().includes(q) ||
        (c.phone && c.phone.includes(q))
      );
      citizenSearchResults = matches.map(withDefaultMugshot);
      return { ok: true, citizens: matches.map(withDefaultMugshot) };
    }
    const resp = await nuiPost('cortex_mdt:searchCitizens', { query });
    if (resp?.ok) {
      citizenSearchResults = (resp.citizens || []).map(withDefaultMugshot);
    }
    return resp;
  }

  function _cacheCitizen(citizen, extras) {
    if (!citizen?.citizen_id) return;
    const normalizedCitizen = withDefaultMugshot(citizen);
    const entry = {
      citizen: normalizedCitizen,
      vehicles: extras.vehicles || [],
      licenses: extras.licenses || [],
      reports: extras.reports || [],
      warrants: extras.warrants || [],
      bolos: extras.bolos || [],
      cachedAt: Date.now(),
    };
    citizenSessionCache = new Map(citizenSessionCache).set(normalizedCitizen.citizen_id, entry);

    // Update recent citizens list (most recent first, max 20)
    const existing = recentCitizens.filter(c => c.citizen_id !== normalizedCitizen.citizen_id);
    const flagsRaw = normalizedCitizen.flags || [];
    let flagsArr = [];
    if (Array.isArray(flagsRaw)) {
      flagsArr = flagsRaw;
    } else if (typeof flagsRaw === 'string') {
      try {
        const parsed = JSON.parse(flagsRaw);
        flagsArr = Array.isArray(parsed) ? parsed : [];
      } catch {
        flagsArr = [];
      }
    }
    recentCitizens = [
      {
        citizen_id: normalizedCitizen.citizen_id,
        first_name: normalizedCitizen.first_name,
        last_name: normalizedCitizen.last_name,
        flags: flagsArr,
        viewedAt: Date.now(),
        mugshot: normalizedCitizen.mugshot || DEFAULT_MUGSHOT_URL,
        dob: normalizedCitizen.dob || null,
        gender: normalizedCitizen.gender || null,
        occupation: normalizedCitizen.occupation || normalizedCitizen.job_title || null,
        fingerprint: normalizedCitizen.fingerprint || null,
        phone: normalizedCitizen.phone || null,
      },
      ...existing,
    ].slice(0, 20);
  }

  function getCitizenFromCache(citizenId) {
    return citizenSessionCache.get(citizenId) || null;
  }

  async function getCitizen(citizenId) {
    if (isEnvBrowser()) {
      const mock = MOCK_CITIZENS.find(c => c.citizen_id === citizenId);
      if (!mock) {
        selectedCitizen = null;
        citizenVehicles = [];
        citizenLicenses = [];
        citizenReports = [];
        citizenWarrants = [];
        citizenBolos = [];
        return { ok: true };
      }
      const veh = MOCK_CITIZEN_VEHICLES.filter(v => v.owner_citizen_id === citizenId);
      const lic = MOCK_CITIZEN_LICENSES.filter(l => l.citizen_id === citizenId);
      selectedCitizen = withDefaultMugshot({ ...mock, vehicles: veh, licenses: lic, reports: [], warrants: [], bolos: [] });
      citizenVehicles = veh;
      citizenLicenses = lic;
      citizenReports = [];
      citizenWarrants = [];
      citizenBolos = [];
      _cacheCitizen(withDefaultMugshot(mock), { vehicles: veh, licenses: lic, reports: [], warrants: [], bolos: [] });
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getCitizen', { citizenId });
    if (resp?.ok) {
      selectedCitizen = {
        ...withDefaultMugshot(resp.citizen || {}),
        vehicles: resp.vehicles || [],
        licenses: resp.licenses || [],
        reports: resp.reports || [],
        warrants: resp.warrants || [],
        bolos: resp.bolos || [],
      };
      citizenVehicles = resp.vehicles;
      citizenLicenses = resp.licenses;
      citizenReports = resp.reports;
      citizenWarrants = resp.warrants;
      citizenBolos = resp.bolos;
      _cacheCitizen(withDefaultMugshot(resp.citizen || {}), {
        vehicles: resp.vehicles || [],
        licenses: resp.licenses || [],
        reports: resp.reports || [],
        warrants: resp.warrants || [],
        bolos: resp.bolos || [],
      });
    }
    return resp;
  }

  async function updateCitizen(data) {
    if (isEnvBrowser()) {
      // Update mock citizen in session cache
      if (data?.citizenId && selectedCitizen) {
        const updated = { ...selectedCitizen };
        if (data.notes !== undefined) updated.notes = data.notes;
        if (data.mugshot !== undefined) updated.mugshot = String(data.mugshot || '').trim() || DEFAULT_MUGSHOT_URL;
        if (data.fingerprint !== undefined) updated.fingerprint = data.fingerprint;
        if (data.occupation !== undefined) updated.occupation = data.occupation;
        if (data.flags !== undefined) updated.flags = data.flags;
        if (data.tags !== undefined) {
          updated.tags = (data.tags || []).map((t) =>
            typeof t === 'string'
              ? { label: t, color: 'blue' }
              : { label: String(t?.label || '').trim(), color: t?.color || 'blue' },
          );
        }
        selectedCitizen = updated;
        _cacheCitizen(updated, {
          vehicles: citizenVehicles || [],
          licenses: citizenLicenses || [],
          reports: citizenReports || [],
          warrants: citizenWarrants || [],
          bolos: citizenBolos || [],
        });
      }
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:updateCitizen', data);
    if (resp?.ok && data?.citizenId) {
      await getCitizen(data.citizenId);
    }
    return resp;
  }

  async function updateCitizenLicenses(dataOrCitizenId, maybeLicenses) {
    const citizenId = typeof dataOrCitizenId === 'object' ? dataOrCitizenId?.citizenId : dataOrCitizenId;
    const licenses = typeof dataOrCitizenId === 'object' ? dataOrCitizenId?.licenses : maybeLicenses;
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateCitizenLicenses', { citizenId, licenses });
    if (resp?.ok && citizenId) {
      await getCitizen(citizenId);
    }
    return resp;
  }

  function clearCitizenSearch() {
    citizenSearchResults = [];
    selectedCitizen = null;
    citizenVehicles = [];
    citizenLicenses = [];
    citizenReports = [];
    citizenWarrants = [];
    citizenBolos = [];
  }

  async function fetchWeapons(filter) {
    if (isEnvBrowser()) {
      weaponsList = [
        {
          id: 1,
          serial_number: 'SN-LSPD-4401',
          owner_citizen_id: 'CIT-20260102-1842',
          owner_name: 'Jordan Mercer',
          weapon_name: 'Pistol',
          weapon_class: 'Sidearm',
          status: 'registered',
          notes: 'Registered after traffic stop follow-up.',
          photo_url: '',
          updated_at: new Date().toISOString(),
        },
      ];
      return { ok: true, weapons: weaponsList };
    }

    const resp = await nuiPost('cortex_mdt:searchWeapons', { query: filter || '' });
    if (resp?.ok) {
      weaponsList = (resp.weapons || []).map(normalizeWeapon);
    }
    return resp;
  }

  async function fetchWeapon(weaponId) {
    if (isEnvBrowser()) {
      selectedWeapon = weaponsList[0] || null;
      weaponHistory = selectedWeapon ? [{
        id: 1,
        action: 'registered',
        officer_id: 1,
        notes: 'Initial registry entry.',
        created_at: new Date().toISOString(),
      }] : [];
      return { ok: true, weapon: selectedWeapon, history: weaponHistory };
    }

    const resp = await nuiPost('cortex_mdt:getWeapon', { weaponId });
    if (resp?.ok) {
      selectedWeapon = resp.weapon ? normalizeWeapon(resp.weapon) : null;
      weaponHistory = resp.history || [];
    }
    return resp;
  }

  const getWeaponRecord = fetchWeapon;

  async function createWeapon(data) {
    if (isEnvBrowser()) return { ok: true, weaponId: Date.now() };
    const payload = {
      ...data,
      weaponName: data.weaponName || data.weapon_name || data.weaponType || [data.make, data.model].filter(Boolean).join(' ').trim(),
      weaponClass: data.weaponClass || data.weapon_class || data.caliber || data.weaponType,
      photoUrl: data.photoUrl || data.photo_url || data.imageUrl || data.image_url,
    };
    const resp = await nuiPost('cortex_mdt:createWeapon', payload);
    if (resp?.ok) {
      await fetchWeapons('');
      if (resp.weaponId) {
        await fetchWeapon(resp.weaponId);
      }
    }
    return resp;
  }

  async function updateWeapon(data) {
    if (isEnvBrowser()) return { ok: true };
    const payload = {
      ...data,
      weaponName: data.weaponName || data.weapon_name || data.weaponType || [data.make, data.model].filter(Boolean).join(' ').trim(),
      weaponClass: data.weaponClass || data.weapon_class || data.caliber || data.weaponType,
      photoUrl: data.photoUrl || data.photo_url || data.imageUrl || data.image_url,
    };
    const resp = await nuiPost('cortex_mdt:updateWeapon', payload);
    if (resp?.ok && data?.weaponId) {
      await fetchWeapons('');
      await fetchWeapon(data.weaponId);
    }
    return resp;
  }

  async function transferWeapon(data) {
    if (isEnvBrowser()) return { ok: true };
    const payload = {
      ...data,
      toCitizenId: data.toCitizenId || data.ownerCitizenId || '',
      toOwnerName: data.toOwnerName || data.ownerName || '',
    };
    const resp = await nuiPost('cortex_mdt:transferWeapon', payload);
    if (resp?.ok && data?.weaponId) {
      await fetchWeapons('');
      await fetchWeapon(data.weaponId);
    }
    return resp;
  }

  async function fetchWeaponAnalytics() {
    if (isEnvBrowser()) {
      weaponAnalytics = {
        total: weaponsList.length,
        registered: weaponsList.filter((weapon) => weapon.status === 'registered').length,
        transferred: weaponsList.filter((weapon) => weapon.status === 'transferred').length,
        seized: weaponsList.filter((weapon) => weapon.status === 'seized').length,
        evidence: weaponsList.filter((weapon) => weapon.status === 'evidence').length,
        stolen: weaponsList.filter((weapon) => weapon.status === 'stolen').length,
        destroyed: weaponsList.filter((weapon) => weapon.status === 'destroyed').length,
        recentTransfers: 1,
      };
      return { ok: true, analytics: weaponAnalytics };
    }

    const resp = await nuiPost('cortex_mdt:getWeaponAnalytics');
    if (resp?.ok) {
      weaponAnalytics = resp.analytics || weaponAnalytics;
    }
    return resp;
  }

  function rememberRecentVehicle(vehicle) {
    if (!vehicle) return;
    const id = vehicle.id ?? vehicle.vehicle_id;
    if (id == null) return;
    let flagsArr = [];
    const raw = vehicle.flags;
    if (Array.isArray(raw)) {
      flagsArr = raw;
    } else if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw);
        flagsArr = Array.isArray(parsed) ? parsed : [];
      } catch {
        flagsArr = [];
      }
    }
    const existing = recentVehicles.filter((v) => v.id !== id);
    recentVehicles = [
      {
        id,
        plate: vehicle.plate || '',
        model: vehicle.model || '',
        owner_name: vehicle.owner_name || null,
        registration_status: vehicle.registration_status || null,
        flags: flagsArr,
        viewedAt: Date.now(),
      },
      ...existing,
    ].slice(0, 20);
  }

  function clearVehicleSearch() {
    vehicleSearchResults = [];
  }

  async function searchVehicles(query) {
    if (isEnvBrowser()) {
      vehicleSearchResults = [];
      return { ok: true, vehicles: [] };
    }
    const resp = await nuiPost('cortex_mdt:searchVehicles', { query });
    if (resp?.ok) {
      vehicleSearchResults = resp.vehicles;
    }
    return resp;
  }

  async function getVehicle(vehicleId) {
    if (isEnvBrowser()) {
      selectedVehicle = null;
      vehicleImpounds = [];
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getVehicle', { vehicleId });
    if (resp?.ok) {
      selectedVehicle = resp.vehicle;
      vehicleImpounds = resp.impounds || [];
      if (resp.vehicle) {
        rememberRecentVehicle(resp.vehicle);
      }
    }
    return resp;
  }

  async function impoundVehicle(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:impoundVehicle', data);
    return resp;
  }

  async function releaseImpound(impoundId) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:releaseImpound', { impoundId });
    return resp;
  }

  async function fetchReports(page, filter) {
    if (isEnvBrowser()) {
      reportsList = [];
      reportsTotal = 0;
      return { ok: true, reports: [], total: 0 };
    }
    const resp = await nuiPost('cortex_mdt:getReports', { page, filter });
    if (resp?.ok) {
      reportsList = resp.reports;
      reportsTotal = resp.total;
    }
    return resp;
  }

  async function getReport(reportId) {
    if (isEnvBrowser()) {
      selectedReport = null;
      reportTimeline = [];
      reportEntities = [];
      reportParticipants = [];
      reportCharges = [];
      reportAttachments = [];
      reportCollaborators = [];
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getReport', { reportId });
    if (resp?.ok) {
      selectedReport = resp.report;
      reportTimeline = resp.timeline;
      reportEntities = resp.entities;
      reportParticipants = resp.participants || [];
      reportCharges = resp.charges || [];
      reportAttachments = resp.attachments || [];
      reportCollaborators = resp.collaborators;
    }
    return resp;
  }

  async function createReport(data) {
    if (isEnvBrowser()) return { ok: true, reportId: 0, reportNumber: 'RPT-00000000-0000' };
    const resp = await nuiPost('cortex_mdt:createReport', data);
    return resp;
  }

  async function updateReport(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateReport', data);
    return resp;
  }

  async function addTimeline(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:addReportTimeline', data);
    return resp;
  }

  async function addEntity(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:addReportEntity', data);
    return resp;
  }

  async function removeEntity(id) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:removeReportEntity', { id });
    return resp;
  }

  async function fetchCases(page) {
    if (isEnvBrowser()) {
      casesList = [];
      casesTotal = 0;
      return { ok: true, cases: [], total: 0 };
    }
    const resp = await nuiPost('cortex_mdt:getCases', { page });
    if (resp?.ok) {
      casesList = resp.cases;
      casesTotal = resp.total;
    }
    return resp;
  }

  async function getCase(caseId) {
    if (isEnvBrowser()) {
      selectedCase = null;
      casePersonnel = [];
      caseLinks = [];
      caseAttachments = [];
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getCase', { caseId });
    if (resp?.ok) {
      selectedCase = resp.case;
      casePersonnel = resp.personnel;
      caseLinks = resp.links;
      caseAttachments = resp.attachments || [];
    }
    return resp;
  }

  async function createCase(data) {
    if (isEnvBrowser()) return { ok: true, caseId: 0, caseNumber: 'CASE-00000000-0000' };
    const resp = await nuiPost('cortex_mdt:createCase', data);
    return resp;
  }

  async function updateCase(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateCase', data);
    return resp;
  }

  async function addCaseLink(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:addCaseLink', data);
    return resp;
  }

  async function removeCaseLink(id) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:removeCaseLink', { id });
    return resp;
  }

  async function addPersonnel(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:addCasePersonnel', data);
    return resp;
  }

  async function removePersonnel(id) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:removeCasePersonnel', { id });
    return resp;
  }

  async function fetchEvidence(page) {
    if (isEnvBrowser()) {
      evidenceList = [];
      evidenceTotal = 0;
      return { ok: true, evidence: [], total: 0 };
    }
    const resp = await nuiPost('cortex_mdt:getEvidence', { page });
    if (resp?.ok) {
      evidenceList = resp.evidence;
      evidenceTotal = resp.total;
    }
    return resp;
  }

  async function getEvidenceRecord(evidenceId) {
    if (isEnvBrowser()) {
      selectedEvidence = null;
      evidenceCustody = [];
      evidenceAttachments = [];
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getEvidenceRecord', { evidenceId });
    if (resp?.ok) {
      selectedEvidence = resp.evidence;
      evidenceCustody = resp.custody;
      evidenceAttachments = resp.attachments || [];
    }
    return resp;
  }

  async function createEvidence(data) {
    if (isEnvBrowser()) return { ok: true, evidenceId: 0, evidenceTag: 'EV-00000000-0000' };
    const resp = await nuiPost('cortex_mdt:createEvidence', data);
    return resp;
  }

  async function updateEvidence(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateEvidence', data);
    return resp;
  }

  async function transferEvidence(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:transferEvidence', data);
    return resp;
  }

  async function addAttachment(data) {
    if (isEnvBrowser()) return { ok: true, attachmentId: Date.now() };
    const resp = await nuiPost('cortex_mdt:addAttachment', data);
    return resp;
  }

  async function removeAttachment(attachmentId, parentType) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:removeAttachment', { attachmentId, parentType });
    return resp;
  }

  async function fetchBolos(filter) {
    if (isEnvBrowser()) {
      bolosList = [];
      return { ok: true, bolos: [] };
    }
    const resp = await nuiPost('cortex_mdt:getBolos', { filter });
    if (resp?.ok) {
      bolosList = resp.bolos;
    }
    return resp;
  }

  async function createBolo(data) {
    if (isEnvBrowser()) return { ok: true, boloId: 0 };
    const resp = await nuiPost('cortex_mdt:createBolo', data);
    return resp;
  }

  async function updateBoloStatus(boloId, status) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateBoloStatus', { boloId, status });
    return resp;
  }

  async function fetchWarrants(filter) {
    if (isEnvBrowser()) {
      warrantsList = [];
      return { ok: true, warrants: [] };
    }
    const resp = await nuiPost('cortex_mdt:getWarrants', { filter });
    if (resp?.ok) {
      warrantsList = resp.warrants;
    }
    return resp;
  }

  async function createWarrant(data) {
    if (isEnvBrowser()) return { ok: true, warrantId: 0 };
    const resp = await nuiPost('cortex_mdt:createWarrant', data);
    return resp;
  }

  async function updateWarrantStatus(warrantId, status) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateWarrantStatus', { warrantId, status });
    return resp;
  }

  async function fetchUnits() {
    if (isEnvBrowser()) {
      unitsList = [];
      return { ok: true, units: [] };
    }
    const resp = await nuiPost('cortex_mdt:getUnits');
    if (resp?.ok) {
      unitsList = (resp.units || []).map((unit) => ({
        ...unit,
        status: normalizeUnitStatus(unit?.status),
        assignment: unit?.assignment || '',
        locationStreet: unit?.locationStreet || '',
        mapArea: unit?.mapArea || '',
      }));
    }
    return resp;
  }

  async function fetchLeaderboard(period = 'week') {
    if (isEnvBrowser()) {
      leaderboardData = {
        summary: {
          totalOfficers: 3,
          totalReports: 41,
          totalArrests: 19,
          averageActivity: 56,
        },
        categories: {
          arrests: [
            { officer_id: 1, name: 'Sofia Rivera', callsign: '1-A-12', rank: 'Sergeant', department: 'LSPD', avatar: '', reports_count: 18, arrests_count: 7, activity_score: 63 },
            { officer_id: 2, name: 'Kenji Nakamura', callsign: '2-L-21', rank: 'Officer', department: 'LSPD', avatar: '', reports_count: 14, arrests_count: 6, activity_score: 57 },
          ],
          reports: [
            { officer_id: 1, name: 'Sofia Rivera', callsign: '1-A-12', rank: 'Sergeant', department: 'LSPD', avatar: '', reports_count: 18, arrests_count: 7, activity_score: 63 },
            { officer_id: 3, name: 'Evan Harper', callsign: '3-B-04', rank: 'Deputy', department: 'BCSO', avatar: '', reports_count: 9, arrests_count: 6, activity_score: 49 },
          ],
          activity: [
            { officer_id: 1, name: 'Sofia Rivera', callsign: '1-A-12', rank: 'Sergeant', department: 'LSPD', avatar: '', reports_count: 18, arrests_count: 7, activity_score: 63 },
            { officer_id: 2, name: 'Kenji Nakamura', callsign: '2-L-21', rank: 'Officer', department: 'LSPD', avatar: '', reports_count: 14, arrests_count: 6, activity_score: 57 },
          ],
        },
        generatedAt: new Date().toISOString(),
        period,
      };
      return { ok: true, leaderboard: leaderboardData };
    }

    const resp = await nuiPost('cortex_mdt:getLeaderboard', { period });
    if (resp?.ok) {
      if (resp.leaderboard) {
        leaderboardData = resp.leaderboard;
      } else {
        const leaders = resp.leaders || [];
        leaderboardData = {
          summary: {
            totalOfficers: resp.summary?.officerCount || leaders.length,
            totalReports: resp.summary?.totalReports || 0,
            totalArrests: resp.summary?.totalArrests || 0,
            totalCases: resp.summary?.totalCases || 0,
          },
          categories: {
            activity: [...leaders].sort((left, right) => (right.activity_score || 0) - (left.activity_score || 0)),
            reports: [...leaders].sort((left, right) => (right.report_count || 0) - (left.report_count || 0)),
            arrests: [...leaders].sort((left, right) => (right.arrest_count || 0) - (left.arrest_count || 0)),
          },
          generatedAt: resp.summary?.generatedAt || new Date().toISOString(),
          period,
        };
      }
    }
    return resp;
  }

  async function fetchCctvCameras() {
    if (isEnvBrowser()) {
      cctvCanManage = true;
      cctvCameras = [
        {
          id: 'CCTV-DEMO-001',
          label: 'Mission Row Lobby',
          type: 'placed',
          model: 'security_cam_03',
          isOnline: true,
          viewerCount: 2,
          coords: { x: 441.77, y: -981.66, z: 34.97 },
          rotation: { x: -18.0, y: 0.0, z: 90.0 },
        },
        {
          id: 'CCTV-DEMO-002',
          label: 'MRPD Garage Gate',
          type: 'placed',
          model: 'security_cam_08',
          isOnline: true,
          viewerCount: 0,
          coords: { x: 454.1, y: -1021.22, z: 29.45 },
          rotation: { x: -12.0, y: 0.0, z: 5.0 },
        },
        {
          id: 'CCTV-DEMO-003',
          label: 'Davis Avenue / Innocence Blvd',
          type: 'placed',
          model: 'cctv_cam_03',
          isOnline: false,
          viewerCount: 0,
          coords: { x: 131.02, y: -1936.18, z: 24.73 },
          rotation: { x: -25.0, y: 0.0, z: 145.0 },
        },
      ];

      return {
        ok: true,
        cameras: cctvCameras,
        canManage: cctvCanManage,
      };
    }

    const resp = await nuiPost('cortex_mdt:getCameras');
    if (resp?.ok) {
      cctvCameras = resp.cameras || [];
      cctvCanManage = resp.canManage === true;
    }

    return resp;
  }

  async function fetchCameraModels() {
    if (isEnvBrowser()) {
      cameraModels = [
        { value: 'security_cam_03', label: 'SECURITY CAM 03 (ba_prop_battle_cctv_cam_01a)', model: 'ba_prop_battle_cctv_cam_01a' },
        { value: 'security_cam_08', label: 'SECURITY CAM 08 (prop_cctv_cam_04c)', model: 'prop_cctv_cam_04c' },
        { value: 'cctv_cam_03', label: 'CCTV CAM 03 (prop_cctv_pole_02)', model: 'prop_cctv_pole_02' },
      ];
      return { ok: true, models: cameraModels, canManage: true };
    }

    const resp = await nuiPost('cortex_mdt:getCameraModels');
    if (resp?.ok) {
      cameraModels = resp.models || [];
    }

    return resp;
  }

  async function createStaticCamera(payload) {
    if (isEnvBrowser()) {
      const camera = {
        id: `CCTV-DEMO-${String(Date.now()).slice(-4)}`,
        label: payload?.label || 'New Camera',
        type: 'placed',
        model: payload?.model || 'security_cam_03',
        isOnline: true,
        viewerCount: 0,
        coords: payload?.coords || { x: 430.0, y: -980.0, z: 35.0 },
        rotation: payload?.rotation || { x: -20.0, y: 0.0, z: 180.0 },
      };
      cctvCameras = [camera, ...cctvCameras];
      return { ok: true, camera, canManage: true };
    }

    const resp = await nuiPost('cortex_mdt:createStaticCamera', payload || {});
    if (resp?.ok && resp.camera) {
      cctvCameras = [resp.camera, ...cctvCameras.filter((camera) => camera.id !== resp.camera.id)];
      cctvCanManage = resp.canManage === true || cctvCanManage;
    }

    return resp;
  }

  async function deleteCamera(cameraId) {
    if (isEnvBrowser()) {
      cctvCameras = cctvCameras.filter((camera) => camera.id !== cameraId);
      if (activeCameraFeed?.id === cameraId) {
        activeCameraFeed = null;
      }
      return { ok: true };
    }

    const resp = await nuiPost('cortex_mdt:deleteCamera', { cameraId });
    if (resp?.ok) {
      cctvCameras = cctvCameras.filter((camera) => camera.id !== cameraId);
      if (activeCameraFeed?.id === cameraId) {
        activeCameraFeed = null;
      }
    }

    return resp;
  }

  async function setCameraOnline(cameraId, isOnline) {
    if (isEnvBrowser()) {
      cctvCameras = cctvCameras.map((camera) => {
        if (camera.id === cameraId) {
          return { ...camera, isOnline: isOnline === true };
        }
        return camera;
      });
      return { ok: true };
    }

    const resp = await nuiPost('cortex_mdt:setCameraOnline', { cameraId, isOnline });
    if (resp?.ok && resp.camera) {
      cctvCameras = cctvCameras.map((camera) => {
        if (camera.id === resp.camera.id) {
          return { ...camera, ...resp.camera };
        }
        return camera;
      });
      if (activeCameraFeed?.id === resp.camera.id && resp.camera.isOnline === false) {
        activeCameraFeed = null;
      }
    }

    return resp;
  }

  async function viewCamera(cameraId) {
    if (isEnvBrowser()) {
      const camera = cctvCameras.find((entry) => entry.id === cameraId);
      if (!camera || camera.isOnline === false) {
        return { ok: false, error: 'Camera is offline.' };
      }
      activeCameraFeed = camera;
      activeBodycamFeed = null;
      return { ok: true, camera };
    }

    const resp = await nuiPost('cortex_mdt:viewCamera', { cameraId });
    if (resp?.ok && resp.camera) {
      activeCameraFeed = resp.camera;
      activeBodycamFeed = null;
    }

    return resp;
  }

  async function fetchBodycams() {
    if (isEnvBrowser()) {
      bodycamsList = [
        {
          source: 12,
          callsign: '1-A-12',
          name: 'John Doe',
          rank: 'Officer',
          department: 'police',
          viewerCount: 1,
          avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=320&q=70&auto=format&fit=crop',
        },
        {
          source: 27,
          callsign: '1-S-27',
          name: 'Sarah Alvarez',
          rank: 'Sergeant',
          department: 'police',
          viewerCount: 0,
          avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=320&q=70&auto=format&fit=crop',
        },
      ];
      return { ok: true, bodycams: bodycamsList };
    }

    const resp = await nuiPost('cortex_mdt:getBodycams');
    if (resp?.ok) {
      bodycamsList = resp.bodycams || [];
    }

    return resp;
  }

  async function viewBodycam(targetSource) {
    if (isEnvBrowser()) {
      const bodycam = bodycamsList.find((entry) => entry.source === targetSource);
      if (!bodycam) {
        return { ok: false, error: 'Bodycam not available.' };
      }
      activeBodycamFeed = bodycam;
      activeCameraFeed = null;
      bodycamLiveLocation = 'Ineos Pl / Power St';
      return { ok: true, bodycam };
    }

    const resp = await nuiPost('cortex_mdt:viewBodycam', { targetSource });
    if (resp?.ok && resp.bodycam) {
      activeBodycamFeed = resp.bodycam;
      activeCameraFeed = null;
    }

    return resp;
  }

  async function stopCameraView() {
    activeCameraFeed = null;
    activeBodycamFeed = null;
    bodycamLiveLocation = '';

    if (isEnvBrowser()) {
      return { ok: true };
    }

    const resp = await nuiPost('cortex_mdt:stopCameraView');
    return resp || { ok: false };
  }

  async function cameraControl(action) {
    if (isEnvBrowser()) {
      return { ok: true };
    }

    const resp = await nuiPost('cortex_mdt:cameraControl', { action });
    return resp || { ok: false };
  }

  async function setBodycamAudio(enabled) {
    if (isEnvBrowser()) {
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:setBodycamAudio', { enabled: enabled === true });
    return resp || { ok: false };
  }

  async function fetchCharges() {
    if (isEnvBrowser()) {
      chargesList = normalizeChargesList(DEFAULT_CHARGES);
      return { ok: true, charges: chargesList };
    }

    const resp = await nuiPost('cortex_mdt:getCharges');
    if (resp?.ok && resp.charges) {
      chargesList = normalizeChargesList(resp.charges);
      return resp;
    }

    chargesList = normalizeChargesList(DEFAULT_CHARGES);
    return resp || { ok: false, charges: chargesList };
  }

  async function updateCharge(data) {
    const nextCharges = applyChargePatch(chargesList.length ? chargesList : DEFAULT_CHARGES, data);

    if (isEnvBrowser()) {
      chargesList = nextCharges;
      const charge = nextCharges.find((entry) => entry.id === Number(data?.chargeId ?? data?.id)) || null;
      return { ok: true, charge, charges: nextCharges };
    }

    const resp = await nuiPost('cortex_mdt:updateCharge', data);
    if (resp?.ok) {
      if (resp.charge) {
        chargesList = applyChargePatch(nextCharges, resp.charge);
      } else if (resp.charges) {
        chargesList = normalizeChargesList(resp.charges);
      } else {
        chargesList = nextCharges;
      }
    }

    return resp || { ok: false };
  }

  function buildOfficerProfilePayload(officerData = mdtStore.officer, opts = {}) {
    const profile = officerData || {};
    const fw = String(profile.frameworkMode || '').toLowerCase();
    const isStandalone = fw === 'standalone';

    let firstName = profile.firstName || profile.first_name || '';
    let lastName = profile.lastName || profile.last_name || '';
    let useFrameworkDisplayName = false;

    if (isStandalone) {
      const sf = String(mdtStore.settings.officerDisplayFirstName || '').trim();
      const sl = String(mdtStore.settings.officerDisplayLastName || '').trim();
      if (sf || sl) {
        firstName = sf || firstName;
        lastName = sl || lastName;
      } else if (opts.forceFrameworkDisplayName) {
        useFrameworkDisplayName = true;
      }
    }

    const payload = {
      firstName,
      lastName,
      rank: profile.rank || '',
      callsign: profile.callsign || '',
      departmentKey: profile.departmentKey || profile.department || '',
    };
    if (useFrameworkDisplayName) {
      payload.useFrameworkDisplayName = true;
    }
    return payload;
  }

  async function registerOfficer(officerData) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:registerOfficer', buildOfficerProfilePayload(officerData));
    if (resp?.ok && resp.officerId) {
      mdtStore.officer = { officerId: resp.officerId };
    }
    return resp;
  }

  async function saveOfficerAvatar(avatarUrl) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:saveOfficerAvatar', { avatarUrl });
    return resp || { ok: false };
  }

  async function ersBiometricLogin() {
    if (isEnvBrowser()) return { ok: true, shiftType: 'police' };
    const resp = await nuiPost('cortex_mdt:ersBiometricLogin');
    return resp || { ok: false };
  }

  async function updateUnitStatus(status, assignment, opts = {}) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateUnitStatus', { status, assignment });
    if (resp?.ok) {
      await refreshDutyStateViews();
      if (!opts.silent) {
        playMdtSound('status');
      }
    }
    return resp;
  }

  async function goOnDuty() {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:goOnDuty', buildOfficerProfilePayload());
    if (resp?.ok) {
      await refreshDutyStateViews();
    }
    return resp;
  }

  async function goOffDuty() {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:goOffDuty');
    if (resp?.ok) {
      await refreshDutyStateViews();
    }
    return resp;
  }

  async function fetchRoster() {
    if (isEnvBrowser()) {
      adminRoster = [];
      return { ok: true, officers: [] };
    }
    const resp = await nuiPost('cortex_mdt:getRoster');
    if (resp?.ok) {
      adminRoster = resp.officers;
    }
    return resp;
  }

  async function updateOfficer(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateOfficerAdmin', data);
    return resp;
  }

  async function fetchAuditLogs(page, filter) {
    if (isEnvBrowser()) {
      adminAuditLogs = [];
      return { ok: true, logs: [] };
    }
    const resp = await nuiPost('cortex_mdt:getAuditLogs', { page, filter });
    if (resp?.ok) {
      adminAuditLogs = Number(page) > 1 ? [...adminAuditLogs, ...(resp.logs || [])] : (resp.logs || []);
    }
    return resp;
  }

  async function fetchSettings() {
    if (isEnvBrowser()) {
      adminSettings = {};
      return { ok: true, settings: {} };
    }
    const resp = await nuiPost('cortex_mdt:getSettings');
    if (resp?.ok) {
      adminSettings = resp.settings;
    }
    return resp;
  }

  async function updateSetting(key, value) {
    if (isEnvBrowser()) {
      if (key === 'motd') dashboardMotd = value;
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:updateSetting', { key, value });
    if (resp?.ok) {
      adminSettings = { ...adminSettings, [key]: value };
      if (key === 'motd') dashboardMotd = value;
    }
    return resp;
  }

  async function createAnnouncement(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:createAnnouncement', data);
    return resp;
  }

  async function deleteAnnouncement(id) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:deleteAnnouncement', { id });
    return resp;
  }

  async function globalSearch(query) {
    if (isEnvBrowser()) {
      globalSearchResults = {};
      return { ok: true, results: {} };
    }
    const resp = await nuiPost('cortex_mdt:globalSearch', { query });
    if (resp?.ok) {
      globalSearchResults = resp.results;
    }
    return resp;
  }

  async function fetchConfig() {
    if (isEnvBrowser()) {
      configData = {};
      return { ok: true, config: {} };
    }
    const resp = await nuiPost('cortex_mdt:getConfig');
    if (resp?.ok) {
      configData = resp.config || {};
    }
    return resp;
  }

  async function fetchLicenseTypes() {
    if (isEnvBrowser()) {
      licenseTypesList = [
        { id: 1, type_id: 'driver', name: "Driver's License", description: 'Authorizes operation of non-commercial motor vehicles on public roadways. Required for all vehicle classes up to Class C.', active: 1 },
        { id: 2, type_id: 'pilot', name: "Pilot's License", description: 'Certifies the holder to operate fixed-wing and rotary aircraft within state airspace.', active: 1 },
        { id: 3, type_id: 'weapon', name: 'Weapon Carry Permit', description: 'Authorizes the concealed or open carry of a registered firearm within state limits.', active: 1 },
        { id: 4, type_id: 'hunting', name: 'Hunting License', description: 'Permits the holder to hunt designated game species during regulated seasons.', active: 1 },
        { id: 5, type_id: 'fishing', name: 'Fishing License', description: 'Authorizes recreational and sport fishing in public waterways, lakes, and coastal regions within state jurisdiction.', active: 1 },
        { id: 6, type_id: 'business', name: 'Business Operating License', description: 'Required for any legal commercial entity conducting business within the state.', active: 1 },
        { id: 7, type_id: 'food_vendor', name: 'Food Vendor Permit', description: 'Certifies the holder to prepare, handle, and sell food products to the public.', active: 1 },
        { id: 8, type_id: 'real_estate', name: 'Real Estate Agent License', description: 'Authorizes the holder to broker, list, and facilitate the sale or lease of residential and commercial property.', active: 1 },
        { id: 9, type_id: 'medical', name: 'Medical Practice License', description: 'Authorizes the holder to practice medicine, prescribe treatment, and perform medical procedures.', active: 1 },
        { id: 10, type_id: 'security', name: 'Security Guard Card', description: 'Certifies the holder to work as a licensed private security officer.', active: 1 },
        { id: 11, type_id: 'liquor', name: 'Liquor License', description: 'Authorizes the sale, service, and distribution of alcoholic beverages at an approved establishment.', active: 1 },
        { id: 12, type_id: 'firearms_dealer', name: 'Federal Firearms License (FFL)', description: 'Authorizes the holder to engage in the business of manufacturing, importing, or dealing firearms and ammunition.', active: 1 },
        { id: 13, type_id: 'commercial_driver', name: 'Commercial Driver License (CDL)', description: 'Authorizes operation of commercial and heavy vehicles including tractor-trailers, buses, and vehicles carrying hazardous materials.', active: 1 },
        { id: 14, type_id: 'motorcycle', name: 'Motorcycle Endorsement', description: 'Authorizes operation of two-wheeled and three-wheeled motorcycles on all public roadways.', active: 1 },
        { id: 15, type_id: 'legal', name: 'Legal Practice License', description: 'Authorizes the holder to practice law, represent clients in court, and provide legal counsel.', active: 1 },
      ];
      return { ok: true, licenses: licenseTypesList };
    }
    const resp = await nuiPost('cortex_mdt:fetchLicenseTypes');
    if (resp?.ok && resp.licenses?.length) {
      licenseTypesList = resp.licenses;
      return resp;
    }
    if (!configData) {
      await fetchConfig();
    }
    const cfgLicenses = configData?.licenseTypes || [];
    if (cfgLicenses.length) {
      licenseTypesList = cfgLicenses.map((lt, i) => ({
        id: i + 1,
        type_id: lt.id,
        name: lt.label,
        description: lt.description || '',
        active: 1,
      }));
      return { ok: true, licenses: licenseTypesList };
    }
    return resp;
  }

  async function createLicenseType(data) {
    if (isEnvBrowser()) {
      const newLic = {
        id: licenseTypesList.length + 1,
        type_id: (data.name || '').toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, ''),
        name: data.name,
        description: data.description || '',
        active: 1,
      };
      licenseTypesList = [...licenseTypesList, newLic];
      return { ok: true, license: newLic };
    }
    const resp = await nuiPost('cortex_mdt:createLicenseType', data);
    if (resp?.ok) {
      licenseTypesList = [...licenseTypesList, resp.license];
    }
    return resp;
  }

  async function updateLicenseType(data) {
    if (isEnvBrowser()) {
      licenseTypesList = licenseTypesList.map((l) => {
        if (l.id !== data.id) return l;
        return { ...l, name: data.name ?? l.name, description: data.description ?? l.description, active: data.active != null ? data.active : l.active };
      });
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:updateLicenseType', data);
    if (resp?.ok) {
      licenseTypesList = licenseTypesList.map((l) => {
        if (l.id !== data.id) return l;
        return { ...l, name: data.name ?? l.name, description: data.description ?? l.description, active: data.active != null ? data.active : l.active };
      });
    }
    return resp;
  }

  async function deleteLicenseType(id) {
    if (isEnvBrowser()) {
      licenseTypesList = licenseTypesList.filter((l) => l.id !== id);
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:deleteLicenseType', { id });
    if (resp?.ok) {
      licenseTypesList = licenseTypesList.filter((l) => l.id !== id);
    }
    return resp;
  }

  async function searchOfficers(query) {
    if (isEnvBrowser()) {
      officerResults = [];
      return { ok: true, officers: [] };
    }
    const resp = await nuiPost('cortex_mdt:searchOfficers', { query });
    if (resp?.ok) {
      officerResults = resp.officers;
    }
    return resp;
  }

  async function issueCitation(data) {
    if (isEnvBrowser()) {
      return {
        ok: true,
        citation: {
          id: 1,
          citation_number: 'CIT-20260425-0001',
          report_number: data.reportId ? `RPT-${data.reportId}` : 'RPT-20260425-0001',
          report_id: data.reportId || 1,
          report_title: 'Traffic Citation',
          issued_by: {
            callsign: '1-A-12',
            name: 'Officer Name',
            rank: 'Sergeant',
            department: 'Los Santos Police Department',
            department_short: 'LSPD',
          },
          issued_to: {
            citizen_id: data.citizenId || 'UNKNOWN',
            name: data.playerName || 'Unknown',
          },
          issued_at: new Date().toISOString(),
          status: 'pending',
          total_fine: 150,
          charges: [{ charge: 'Speeding', severity: 'infraction', count: 1, fine: 150, notes: '' }],
          notes: data.notes || '',
        },
      };
    }
    return await nuiPost('cortex_mdt:issueCitation', data);
  }

  async function getMyCitations() {
    if (isEnvBrowser()) {
      return {
        ok: true,
        citations: [
          {
            id: 1,
            citation_number: 'CIT-20260425-0001',
            report_number: 'RPT-20260425-0001',
            report_title: 'Traffic Citation',
            issued_by: {
              callsign: '1-A-12', name: 'Officer Name', rank: 'Sergeant',
              department: 'Los Santos Police Department', department_short: 'LSPD',
            },
            issued_to: { citizen_id: 'STN-000001', name: 'John Doe' },
            issued_at: new Date().toISOString(),
            status: 'pending',
            total_fine: 150,
            charges: [{ charge: 'Speeding', severity: 'infraction', count: 1, fine: 150, notes: '' }],
            notes: '',
          },
        ],
      };
    }
    return await nuiPost('cortex_mdt:getMyCitations');
  }

  async function getCitation(citationId) {
    if (isEnvBrowser()) {
      return getMyCitations().then(r => ({
        ok: true,
        citation: r.citations.find(c => c.id === citationId) || null,
      }));
    }
    return await nuiPost('cortex_mdt:getCitation', { citationId });
  }

  async function markCitationViewed(citationId) {
    if (isEnvBrowser()) {
      return { ok: true };
    }
    return await nuiPost('cortex_mdt:markCitationViewed', { citationId });
  }

  async function fetchDispatch() {
    if (isEnvBrowser()) {
      dispatchCalls = [
        {
          id: '1', code: '10-99', title: 'Officer Panic', location: 'Davis Ave & Innocence Blvd',
          priority: 1, severity: 'Critical', unitCount: 2, coords: { x: 112.0, y: -1960.0, z: 21.0 },
          street: 'Davis Ave', postal: '102', primaryCallsign: '1-L-14', vehiclePlate: '',
          vehicleMake: '', vehicleModel: '', codeName: '', icon: '', sourceSystem: 'local',
          createdAt: new Date(Date.now() - 120000).toISOString(),
        },
        {
          id: '2', code: '10-11', title: 'Traffic Stop', location: 'Strawberry Ave & Capital Blvd',
          priority: 3, severity: 'Low', unitCount: 1, coords: { x: 65.0, y: -1880.0, z: 22.0 },
          street: 'Strawberry Ave', postal: '305', primaryCallsign: '2-A-19', vehiclePlate: 'ABC 123',
          vehicleMake: 'Vapid', vehicleModel: 'Stanier', codeName: '', icon: '', sourceSystem: 'local',
          createdAt: new Date(Date.now() - 300000).toISOString(),
        },
        {
          id: '3', code: '10-71', title: 'Shots Fired', location: 'Forum Dr, Strawberry',
          priority: 1, severity: 'Critical', unitCount: 0, coords: { x: -140.0, y: -1590.0, z: 35.0 },
          street: 'Forum Dr', postal: '457', primaryCallsign: '', vehiclePlate: '',
          vehicleMake: '', vehicleModel: '', codeName: '', icon: '', sourceSystem: 'cortex-dispatch',
          createdAt: new Date(Date.now() - 60000).toISOString(),
        },
      ];
      dispatchActiveUnits = [
        { source: 1, callsign: '1-L-14', name: 'John Smith', availability: 'Available', dutyStatus: 'On Duty', coords: { x: 120.0, y: -1950.0, z: 21.0 } },
        { source: 2, callsign: '2-A-19', name: 'Jane Doe', availability: 'En Route', dutyStatus: 'On Duty', coords: { x: 420.0, y: -980.0, z: 30.0 } },
        { source: 3, callsign: '3-B-07', name: 'Mike Torres', availability: 'On Scene', dutyStatus: 'On Duty', coords: { x: -450.0, y: -320.0, z: 35.0 } },
      ];
      return { ok: true, calls: dispatchCalls, units: dispatchActiveUnits };
    }
    const resp = await nuiPost('cortex_mdt:getDispatch');
    if (resp?.ok) {
      dispatchCalls = resp.calls || [];
      dispatchActiveUnits = resp.units || [];
      if (selectedDispatchId && !dispatchCalls.find((call) => call.id === selectedDispatchId)) {
        selectedDispatchId = null;
      }
    }
    return resp;
  }

  async function runDispatchAction(callback) {
    dispatchActionState = { busy: true, error: '' };
    try {
      const resp = await callback();
      if (resp?.ok) {
        dispatchActionState = { busy: false, error: '' };
      } else {
        dispatchActionState = { busy: false, error: resp?.error || 'Dispatch action failed.' };
      }
      return resp;
    } catch (error) {
      dispatchActionState = { busy: false, error: error?.message || 'Dispatch action failed.' };
      return { ok: false, error: dispatchActionState.error };
    }
  }

  async function attachDispatchCall(dispatchId) {
    if (isEnvBrowser()) return { ok: true };
    return runDispatchAction(() => nuiPost('cortex_mdt:attachDispatchCall', { dispatchId }));
  }

  async function detachDispatchCall(dispatchId) {
    if (isEnvBrowser()) return { ok: true };
    return runDispatchAction(() => nuiPost('cortex_mdt:detachDispatchCall', { dispatchId }));
  }

  async function setDispatchWaypoint(coords) {
    if (isEnvBrowser()) return { ok: true };
    if (!coords) return { ok: false };
    const resp = await nuiPost('cortex_mdt:setWaypoint', { coords });
    return resp;
  }

  async function triggerDispatchPanic(payload) {
    if (isEnvBrowser()) return { ok: true };
    return runDispatchAction(() => nuiPost('cortex_mdt:triggerPanic', payload || {}));
  }

  async function createTrafficStopCall(payload) {
    if (isEnvBrowser()) return { ok: true };
    return runDispatchAction(() => nuiPost('cortex_mdt:createTrafficStopCall', payload || {}));
  }

  async function updateDispatchCall(dispatchId, patch) {
    if (isEnvBrowser()) return { ok: true };
    return runDispatchAction(() => nuiPost('cortex_mdt:updateDispatchCall', { dispatchId, ...(patch || {}) }));
  }

  async function closeDispatchCall(dispatchId, reason) {
    if (isEnvBrowser()) return { ok: true };
    return runDispatchAction(() => nuiPost('cortex_mdt:closeDispatchCall', { dispatchId, reason }));
  }

  async function addDispatchNote(dispatchId, text) {
    if (isEnvBrowser()) return { ok: true };
    return runDispatchAction(() => nuiPost('cortex_mdt:addDispatchNote', { dispatchId, text }));
  }

  async function markDispatchCode4(dispatchId) {
    if (isEnvBrowser()) return { ok: true };
    return runDispatchAction(() => nuiPost('cortex_mdt:markDispatchCode4', { dispatchId }));
  }

  // ── FTO (Field Training Officer) ──────────────────────────────
  async function fetchFtoRecords() {
    if (isEnvBrowser()) return { ok: true, records: [] };
    try {
      const resp = await nuiPost('cortex_mdt:getFtoRecords');
      return resp;
    } catch { return { ok: false }; }
  }

  async function createFtoRecord(data) {
    if (isEnvBrowser()) return { ok: true, record: { id: Date.now(), ...data, created_at: new Date().toISOString(), updated_at: new Date().toISOString() } };
    try {
      const resp = await nuiPost('cortex_mdt:createFtoRecord', data);
      return resp;
    } catch { return { ok: false }; }
  }

  async function updateFtoRecord(data) {
    if (isEnvBrowser()) return { ok: true };
    try {
      const resp = await nuiPost('cortex_mdt:updateFtoRecord', data);
      return resp;
    } catch { return { ok: false }; }
  }

  // ── Civilian Identity Update ──────────────────────────────────
  async function updateStandaloneCivilian(data) {
    if (isEnvBrowser()) return { ok: true };
    try {
      const resp = await nuiPost('cortex_mdt:updateStandaloneCivilian', data);
      if (resp?.ok) applyStandaloneCivilianState(resp);
      return resp;
    } catch { return { ok: false }; }
  }

  // ── Civilian Records ──────────────────────────────────────────
  async function fetchCivilianRecords(citizenId) {
    if (isEnvBrowser()) return { ok: true, records: { citations: [], warrants: [], arrests: [] } };
    try {
      const resp = await nuiPost('cortex_mdt:getCivilianRecords', { citizenId });
      return resp;
    } catch { return { ok: false }; }
  }

  return {
    get standaloneCitizens() { return standaloneCitizens; },
    set standaloneCitizens(v) { standaloneCitizens = v; },
    get standaloneVehicles() { return standaloneVehicles; },
    set standaloneVehicles(v) { standaloneVehicles = v; },
    get standaloneCivilianState() { return standaloneCivilianState; },
    set standaloneCivilianState(v) { standaloneCivilianState = v; },
    fetchStandaloneCivilianState,
    generateStandaloneCivilian,
    registerStandaloneCivilian,
    claimStandaloneCivilian,
    unclaimStandaloneCivilian,
    deleteStandaloneCivilian,
    registerStandaloneVehicle,
    registerCurrentStandaloneVehicle,

    get dashboardStats() { return dashboardStats; },
    set dashboardStats(v) { dashboardStats = v; },
    get dashboardMotd() { return dashboardMotd; },
    set dashboardMotd(v) { dashboardMotd = v; },
    get dashboardBolos() { return dashboardBolos; },
    set dashboardBolos(v) { dashboardBolos = v; },
    get dashboardAnnouncements() { return dashboardAnnouncements; },
    set dashboardAnnouncements(v) { dashboardAnnouncements = v; },
    get dashboardDispatchCalls() { return dashboardDispatchCalls; },
    set dashboardDispatchCalls(v) { dashboardDispatchCalls = v; },
    get dashboardRecentReports() { return dashboardRecentReports; },
    set dashboardRecentReports(v) { dashboardRecentReports = v; },
    get dashboardOnDutyOfficers() { return dashboardOnDutyOfficers; },
    set dashboardOnDutyOfficers(v) { dashboardOnDutyOfficers = v; },
    get dashboardChatMessages() { return dashboardChatMessages; },
    set dashboardChatMessages(v) { dashboardChatMessages = v; },
    fetchDashboard,
    sendChatMessage,

    get citizenSearchResults() { return citizenSearchResults; },
    set citizenSearchResults(v) { citizenSearchResults = v; },
    get selectedCitizen() { return selectedCitizen; },
    set selectedCitizen(v) { selectedCitizen = v; },
    get citizenVehicles() { return citizenVehicles; },
    set citizenVehicles(v) { citizenVehicles = v; },
    get citizenLicenses() { return citizenLicenses; },
    set citizenLicenses(v) { citizenLicenses = v; },
    get citizenReports() { return citizenReports; },
    set citizenReports(v) { citizenReports = v; },
    get citizenWarrants() { return citizenWarrants; },
    set citizenWarrants(v) { citizenWarrants = v; },
    get citizenBolos() { return citizenBolos; },
    set citizenBolos(v) { citizenBolos = v; },
    searchCitizens,
    getCitizen,
    getCitizenFromCache,
    get recentCitizens() { return recentCitizens; },
    get citizenSessionCache() { return citizenSessionCache; },
    updateCitizen,
    updateCitizenLicenses,
    clearCitizenSearch,

    get weaponsList() { return weaponsList; },
    set weaponsList(v) { weaponsList = v; },
    get selectedWeapon() { return selectedWeapon; },
    set selectedWeapon(v) { selectedWeapon = v; },
    get weaponHistory() { return weaponHistory; },
    set weaponHistory(v) { weaponHistory = v; },
    get weaponAnalytics() { return weaponAnalytics; },
    set weaponAnalytics(v) { weaponAnalytics = v; },
    fetchWeapons,
    fetchWeapon,
    getWeaponRecord,
    createWeapon,
    updateWeapon,
    transferWeapon,
    fetchWeaponAnalytics,

    get vehicleSearchResults() { return vehicleSearchResults; },
    set vehicleSearchResults(v) { vehicleSearchResults = v; },
    get selectedVehicle() { return selectedVehicle; },
    set selectedVehicle(v) { selectedVehicle = v; },
    get vehicleImpounds() { return vehicleImpounds; },
    set vehicleImpounds(v) { vehicleImpounds = v; },
    get recentVehicles() { return recentVehicles; },
    searchVehicles,
    getVehicle,
    rememberRecentVehicle,
    clearVehicleSearch,
    impoundVehicle,
    releaseImpound,

    get reportsList() { return reportsList; },
    set reportsList(v) { reportsList = v; },
    get reportsTotal() { return reportsTotal; },
    set reportsTotal(v) { reportsTotal = v; },
    get selectedReport() { return selectedReport; },
    set selectedReport(v) { selectedReport = v; },
    get reportTimeline() { return reportTimeline; },
    set reportTimeline(v) { reportTimeline = v; },
    get reportEntities() { return reportEntities; },
    set reportEntities(v) { reportEntities = v; },
    get reportParticipants() { return reportParticipants; },
    set reportParticipants(v) { reportParticipants = v; },
    get reportCharges() { return reportCharges; },
    set reportCharges(v) { reportCharges = v; },
    get reportAttachments() { return reportAttachments; },
    set reportAttachments(v) { reportAttachments = v; },
    get reportCollaborators() { return reportCollaborators; },
    set reportCollaborators(v) { reportCollaborators = v; },
    fetchReports,
    getReport,
    createReport,
    updateReport,
    addTimeline,
    addEntity,
    removeEntity,

    get casesList() { return casesList; },
    set casesList(v) { casesList = v; },
    get casesTotal() { return casesTotal; },
    set casesTotal(v) { casesTotal = v; },
    get selectedCase() { return selectedCase; },
    set selectedCase(v) { selectedCase = v; },
    get casePersonnel() { return casePersonnel; },
    set casePersonnel(v) { casePersonnel = v; },
    get caseLinks() { return caseLinks; },
    set caseLinks(v) { caseLinks = v; },
    get caseAttachments() { return caseAttachments; },
    set caseAttachments(v) { caseAttachments = v; },
    fetchCases,
    getCase,
    createCase,
    updateCase,
    addCaseLink,
    removeCaseLink,
    addPersonnel,
    removePersonnel,

    get evidenceList() { return evidenceList; },
    set evidenceList(v) { evidenceList = v; },
    get evidenceTotal() { return evidenceTotal; },
    set evidenceTotal(v) { evidenceTotal = v; },
    get selectedEvidence() { return selectedEvidence; },
    set selectedEvidence(v) { selectedEvidence = v; },
    get evidenceCustody() { return evidenceCustody; },
    set evidenceCustody(v) { evidenceCustody = v; },
    get evidenceAttachments() { return evidenceAttachments; },
    set evidenceAttachments(v) { evidenceAttachments = v; },
    fetchEvidence,
    getEvidenceRecord,
    createEvidence,
    updateEvidence,
    transferEvidence,
    addAttachment,
    removeAttachment,

    get bolosList() { return bolosList; },
    set bolosList(v) { bolosList = v; },
    fetchBolos,
    createBolo,
    updateBoloStatus,

    get warrantsList() { return warrantsList; },
    set warrantsList(v) { warrantsList = v; },
    fetchWarrants,
    createWarrant,
    updateWarrantStatus,

    get unitsList() { return unitsList; },
    set unitsList(v) { unitsList = v; },
    fetchUnits,

    get leaderboardData() { return leaderboardData; },
    set leaderboardData(v) { leaderboardData = v; },
    fetchLeaderboard,

    get cctvCameras() { return cctvCameras; },
    set cctvCameras(v) { cctvCameras = v; },
    get cameraModels() { return cameraModels; },
    set cameraModels(v) { cameraModels = v; },
    get cctvCanManage() { return cctvCanManage; },
    set cctvCanManage(v) { cctvCanManage = v; },
    get activeCameraFeed() { return activeCameraFeed; },
    set activeCameraFeed(v) { activeCameraFeed = v; },
    fetchCctvCameras,
    fetchCameraModels,
    createStaticCamera,
    deleteCamera,
    setCameraOnline,
    viewCamera,

    get bodycamsList() { return bodycamsList; },
    set bodycamsList(v) { bodycamsList = v; },
    get activeBodycamFeed() { return activeBodycamFeed; },
    set activeBodycamFeed(v) { activeBodycamFeed = v; },
    get bodycamLiveLocation() { return bodycamLiveLocation; },
    set bodycamLiveLocation(v) { bodycamLiveLocation = typeof v === 'string' ? v : ''; },
    fetchBodycams,
    viewBodycam,
    stopCameraView,
    cameraControl,
    setBodycamAudio,

    get chargesList() { return chargesList; },
    set chargesList(v) { chargesList = v; },
    fetchCharges,
    updateCharge,

    get licenseTypesList() { return licenseTypesList; },
    set licenseTypesList(v) { licenseTypesList = v; },
    fetchLicenseTypes,
    createLicenseType,
    updateLicenseType,
    deleteLicenseType,

    registerOfficer,
    buildOfficerProfilePayload,
    saveOfficerAvatar,
    ersBiometricLogin,
    updateUnitStatus,
    goOnDuty,
    goOffDuty,

    get adminRoster() { return adminRoster; },
    set adminRoster(v) { adminRoster = v; },
    get adminAuditLogs() { return adminAuditLogs; },
    set adminAuditLogs(v) { adminAuditLogs = v; },
    get adminSettings() { return adminSettings; },
    set adminSettings(v) { adminSettings = v; },
    fetchRoster,
    updateOfficer,
    fetchAuditLogs,
    fetchSettings,
    updateSetting,
    createAnnouncement,
    deleteAnnouncement,

    get globalSearchResults() { return globalSearchResults; },
    set globalSearchResults(v) { globalSearchResults = v; },
    globalSearch,

    get configData() { return configData; },
    set configData(v) { configData = v; },
    fetchConfig,

    get officerResults() { return officerResults; },
    set officerResults(v) { officerResults = v; },
    searchOfficers,

    // Citations
    issueCitation,
    getMyCitations,
    getCitation,
    markCitationViewed,

    get dispatchCalls() { return dispatchCalls; },
    set dispatchCalls(v) { dispatchCalls = v; },
    get dispatchActiveUnits() { return dispatchActiveUnits; },
    set dispatchActiveUnits(v) { dispatchActiveUnits = v; },
    get selectedDispatchId() { return selectedDispatchId; },
    set selectedDispatchId(v) { selectedDispatchId = v; },
    get dispatchActionState() { return dispatchActionState; },
    set dispatchActionState(v) { dispatchActionState = v; },
    get dispatchNoteDraft() { return dispatchNoteDraft; },
    set dispatchNoteDraft(v) { dispatchNoteDraft = v; },
    get dispatchCloseReason() { return dispatchCloseReason; },
    set dispatchCloseReason(v) { dispatchCloseReason = v; },
    fetchDispatch,
    attachDispatchCall,
    detachDispatchCall,
    setDispatchWaypoint,
    triggerDispatchPanic,
    createTrafficStopCall,
    updateDispatchCall,
    closeDispatchCall,
    addDispatchNote,
    markDispatchCode4,

    fetchFtoRecords,
    createFtoRecord,
    updateFtoRecord,
    updateStandaloneCivilian,
    fetchCivilianRecords,
  };
}

export const dataStore = createDataStore();
