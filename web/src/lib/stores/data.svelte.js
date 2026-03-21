import { nuiPost, isEnvBrowser } from '../utils/nui.js';
import { mdtStore } from './mdt.svelte.js';

function createDataStore() {
  let standaloneCitizens = $state([]);
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

  let vehicleSearchResults = $state([]);
  let selectedVehicle = $state(null);
  let vehicleImpounds = $state([]);

  let reportsList = $state([]);
  let reportsTotal = $state(0);
  let selectedReport = $state(null);
  let reportTimeline = $state([]);
  let reportEntities = $state([]);
  let reportCollaborators = $state([]);

  let casesList = $state([]);
  let casesTotal = $state(0);
  let selectedCase = $state(null);
  let casePersonnel = $state([]);
  let caseLinks = $state([]);

  let evidenceList = $state([]);
  let evidenceTotal = $state(0);
  let selectedEvidence = $state(null);
  let evidenceCustody = $state([]);

  let bolosList = $state([]);

  let warrantsList = $state([]);

  let unitsList = $state([]);

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

    standaloneCitizens = payload.citizens || [];
    standaloneCivilianState = {
      activeCitizenId: payload.activeCitizenId || null,
      standaloneEnabled: payload.standaloneEnabled === true,
      maxCitizensPerSession: payload.maxCitizensPerSession || 0,
      frameworkMode: payload.frameworkMode || 'standalone',
      error: payload.error || null,
    };

    if (payload.civilian) {
      mdtStore.civilian = payload.civilian;
    }
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
      },
    ];

    standaloneCitizens = mockCitizens;
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
      civilian: mockCitizens[0],
      ...standaloneCivilianState,
    };
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
      };

      standaloneCitizens = [citizen, ...standaloneCitizens];
      return {
        ok: true,
        citizen,
        citizens: standaloneCitizens,
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

  async function claimStandaloneCivilian(citizenId) {
    if (isEnvBrowser()) {
      standaloneCitizens = standaloneCitizens.map((citizen) => ({
        ...citizen,
        claimed: citizen.citizenId === citizenId ? true : citizen.claimed,
        isOwner: citizen.citizenId === citizenId ? true : citizen.isOwner,
        isActive: citizen.citizenId === citizenId,
      }));
      const activeCitizen = standaloneCitizens.find((citizen) => citizen.citizenId === citizenId) || null;
      standaloneCivilianState = {
        ...standaloneCivilianState,
        activeCitizenId: citizenId,
      };
      if (activeCitizen) {
        mdtStore.civilian = activeCitizen;
      }
      return {
        ok: true,
        citizen: activeCitizen,
        civilians: standaloneCitizens,
        citizens: standaloneCitizens,
        civilian: activeCitizen,
        ...standaloneCivilianState,
      };
    }

    const resp = await nuiPost('cortex_mdt:claimStandaloneCivilian', { citizenId });
    if (resp?.ok) {
      applyStandaloneCivilianState(resp);
    }
    return resp;
  }

  async function deleteStandaloneCivilian(citizenId) {
    if (isEnvBrowser()) {
      standaloneCitizens = standaloneCitizens.filter((citizen) => citizen.citizenId !== citizenId);
      const nextActiveCitizen = standaloneCitizens[0] || null;
      standaloneCivilianState = {
        ...standaloneCivilianState,
        activeCitizenId: nextActiveCitizen?.citizenId || null,
      };
      if (nextActiveCitizen) {
        mdtStore.civilian = nextActiveCitizen;
      }
      return {
        ok: true,
        citizens: standaloneCitizens,
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
        { id: 1, callsign: '1-A-12', name: 'John Doe', rank: 'Officer', status: 'available', department: 'LSPD' },
        { id: 2, callsign: '1-A-15', name: 'Sarah Chen', rank: 'Sergeant', status: 'en_route', department: 'LSPD' },
        { id: 3, callsign: '1-L-20', name: 'Marcus Rivera', rank: 'Officer', status: 'on_scene', department: 'LSPD' },
        { id: 4, callsign: '1-X-01', name: 'Alex Kim', rank: 'Corporal', status: 'emergency', department: 'LSPD' },
        { id: 5, callsign: '1-A-22', name: 'Diana Vasquez', rank: 'Officer', status: 'busy', department: 'LSPD' },
        { id: 6, callsign: '2-S-01', name: 'James Harper', rank: 'Deputy', status: 'available', department: 'BCSO' },
        { id: 7, callsign: '2-S-07', name: 'Mia Torres', rank: 'Sr. Deputy', status: 'on_scene', department: 'BCSO' },
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

  async function sendChatMessage(message) {
    if (isEnvBrowser()) {
      const officer = mdtStore.officer;
      const newMsg = {
        id: Date.now(),
        callsign: officer.callsign,
        name: officer.lastName,
        rank: officer.rank ? officer.rank.substring(0, 4) + '.' : 'Ofc.',
        message,
        timestamp: new Date().toISOString(),
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

  async function searchCitizens(query) {
    if (isEnvBrowser()) {
      citizenSearchResults = [];
      return { ok: true, citizens: [] };
    }
    const resp = await nuiPost('cortex_mdt:searchCitizens', { query });
    if (resp?.ok) {
      citizenSearchResults = resp.citizens;
    }
    return resp;
  }

  async function getCitizen(citizenId) {
    if (isEnvBrowser()) {
      selectedCitizen = null;
      citizenVehicles = [];
      citizenLicenses = [];
      citizenReports = [];
      citizenWarrants = [];
      citizenBolos = [];
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getCitizen', { citizenId });
    if (resp?.ok) {
      selectedCitizen = resp.citizen;
      citizenVehicles = resp.vehicles;
      citizenLicenses = resp.licenses;
      citizenReports = resp.reports;
      citizenWarrants = resp.warrants;
      citizenBolos = resp.bolos;
    }
    return resp;
  }

  async function updateCitizen(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateCitizen', data);
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
      vehicleImpounds = resp.impounds;
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
      reportCollaborators = [];
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getReport', { reportId });
    if (resp?.ok) {
      selectedReport = resp.report;
      reportTimeline = resp.timeline;
      reportEntities = resp.entities;
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
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getCase', { caseId });
    if (resp?.ok) {
      selectedCase = resp.case;
      casePersonnel = resp.personnel;
      caseLinks = resp.links;
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
      return { ok: true };
    }
    const resp = await nuiPost('cortex_mdt:getEvidenceRecord', { evidenceId });
    if (resp?.ok) {
      selectedEvidence = resp.evidence;
      evidenceCustody = resp.custody;
    }
    return resp;
  }

  async function createEvidence(data) {
    if (isEnvBrowser()) return { ok: true, evidenceId: 0, evidenceTag: 'EV-00000000-0000' };
    const resp = await nuiPost('cortex_mdt:createEvidence', data);
    return resp;
  }

  async function transferEvidence(data) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:transferEvidence', data);
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
      unitsList = resp.units;
    }
    return resp;
  }

  async function updateUnitStatus(status, assignment) {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateUnitStatus', { status, assignment });
    return resp;
  }

  async function goOnDuty() {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:goOnDuty');
    return resp;
  }

  async function goOffDuty() {
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:goOffDuty');
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
      adminAuditLogs = resp.logs;
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
    if (isEnvBrowser()) return { ok: true };
    const resp = await nuiPost('cortex_mdt:updateSetting', { key, value });
    if (resp?.ok) {
      adminSettings = { ...adminSettings, [key]: value };
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
      configData = resp.config;
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

  return {
    get standaloneCitizens() { return standaloneCitizens; },
    set standaloneCitizens(v) { standaloneCitizens = v; },
    get standaloneCivilianState() { return standaloneCivilianState; },
    set standaloneCivilianState(v) { standaloneCivilianState = v; },
    fetchStandaloneCivilianState,
    generateStandaloneCivilian,
    claimStandaloneCivilian,
    deleteStandaloneCivilian,

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
    updateCitizen,
    clearCitizenSearch,

    get vehicleSearchResults() { return vehicleSearchResults; },
    set vehicleSearchResults(v) { vehicleSearchResults = v; },
    get selectedVehicle() { return selectedVehicle; },
    set selectedVehicle(v) { selectedVehicle = v; },
    get vehicleImpounds() { return vehicleImpounds; },
    set vehicleImpounds(v) { vehicleImpounds = v; },
    searchVehicles,
    getVehicle,
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
    fetchEvidence,
    getEvidenceRecord,
    createEvidence,
    transferEvidence,

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
  };
}

export const dataStore = createDataStore();
