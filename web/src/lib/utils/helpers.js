export function clamp(val, min, max) {
  return Math.min(Math.max(val, min), max);
}

export function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

export function getInitialLastName(firstName, lastName) {
  if (!firstName || !lastName) return '';
  return `${firstName.charAt(0)}. ${lastName}`;
}

export function normalizeCallsign(value) {
  return String(value || '').trim().toUpperCase();
}

const UNIT_STATUS_ALIASES = {
  enroute: 'en_route',
  scene: 'on_scene',
  onscene: 'on_scene',
  'on scene': 'on_scene',
  'en route': 'en_route',
  offduty: 'off_duty',
  'off duty': 'off_duty',
};

const UNIT_STATUS_LABELS = {
  available: 'Available',
  busy: 'Busy',
  en_route: 'En Route',
  on_scene: 'On Scene',
  emergency: 'Emergency',
  off_duty: 'Off Duty',
};

export function normalizeUnitStatus(value, fallback = 'off_duty') {
  const normalized = String(value || '').trim().toLowerCase().replace(/\s+/g, '_');
  if (!normalized) {
    return fallback;
  }

  const mapped = UNIT_STATUS_ALIASES[normalized] || normalized;
  return UNIT_STATUS_LABELS[mapped] ? mapped : fallback;
}

export function getUnitStatusLabel(value) {
  const status = normalizeUnitStatus(value);
  return UNIT_STATUS_LABELS[status] || UNIT_STATUS_LABELS.off_duty;
}

export function isUnitOnDuty(value) {
  return normalizeUnitStatus(value) !== 'off_duty';
}

function buildOfficerName(row = {}) {
  const fullName = String(row.name || '').trim();
  if (fullName) {
    return fullName;
  }

  return `${String(row.first_name || row.firstName || '').trim()} ${String(row.last_name || row.lastName || '').trim()}`.trim();
}

function buildUnitLookupKey(unit = {}) {
  return String(
    unit.source ??
    unit.officer_id ??
    unit.officerId ??
    unit.unitId ??
    normalizeCallsign(unit.callsign)
  ).trim();
}

function normalizeDispatchUnit(unit = {}) {
  const status = normalizeUnitStatus(unit.status);
  return {
    ...unit,
    status,
    availability: getUnitStatusLabel(status),
    dutyStatus: isUnitOnDuty(status) ? 'On Duty' : 'Off Duty',
  };
}

export function mergeDispatchUnits(rosterUnits = [], liveUnits = []) {
  const liveByOfficerId = new Map();
  const liveBySource = new Map();
  const liveByCallsign = new Map();

  for (const liveUnit of liveUnits || []) {
    const normalized = normalizeDispatchUnit(liveUnit);
    const officerId = normalized.officer_id ?? normalized.officerId;
    const source = normalized.source;
    const callsign = normalizeCallsign(normalized.callsign);

    if (officerId !== null && officerId !== undefined && officerId !== '') {
      liveByOfficerId.set(String(officerId), normalized);
    }
    if (source !== null && source !== undefined && source !== '') {
      liveBySource.set(String(source), normalized);
    }
    if (callsign) {
      liveByCallsign.set(callsign, normalized);
    }
  }

  const merged = [];
  const seen = new Set();

  for (const rosterUnit of rosterUnits || []) {
    const status = normalizeUnitStatus(rosterUnit?.status);
    if (!isUnitOnDuty(status)) {
      continue;
    }

    const officerId = rosterUnit?.officer_id ?? rosterUnit?.officerId;
    const source = rosterUnit?.source;
    const callsign = normalizeCallsign(rosterUnit?.callsign);
    const liveUnit =
      (officerId !== null && officerId !== undefined && officerId !== '' && liveByOfficerId.get(String(officerId))) ||
      (source !== null && source !== undefined && source !== '' && liveBySource.get(String(source))) ||
      (callsign && liveByCallsign.get(callsign)) ||
      null;

    const mergedUnit = normalizeDispatchUnit({
      ...liveUnit,
      ...rosterUnit,
      status,
      callsign: rosterUnit?.callsign || liveUnit?.callsign || '',
      name: buildOfficerName(rosterUnit) || buildOfficerName(liveUnit) || 'Unknown',
      department: rosterUnit?.department || rosterUnit?.dept || liveUnit?.department || 'police',
      unitId: rosterUnit?.unitId || liveUnit?.unitId || String(officerId ?? source ?? callsign ?? ''),
      officer_id: officerId ?? liveUnit?.officer_id ?? liveUnit?.officerId ?? null,
      source: liveUnit?.source ?? source ?? null,
      coords: liveUnit?.coords || null,
      assignment: rosterUnit?.assignment || '',
      rank: rosterUnit?.rank || liveUnit?.rank || '',
    });

    const key = buildUnitLookupKey(mergedUnit);
    if (!key || seen.has(key)) {
      continue;
    }

    seen.add(key);
    merged.push(mergedUnit);
  }

  merged.sort((left, right) => {
    const leftCallsign = normalizeCallsign(left.callsign);
    const rightCallsign = normalizeCallsign(right.callsign);
    return leftCallsign.localeCompare(rightCallsign);
  });

  return merged;
}

export function findUnitForOfficer(units, officer) {
  if (!Array.isArray(units) || !officer) return null;

  const officerId = officer.officerId ?? officer.officer_id ?? officer.id ?? null;
  if (officerId !== null && officerId !== undefined && officerId !== '') {
    const matchedById = units.find((unit) => {
      const unitOfficerId = unit?.officer_id ?? unit?.officerId ?? unit?.id ?? null;
      return unitOfficerId !== null && unitOfficerId !== undefined && String(unitOfficerId) === String(officerId);
    });

    if (matchedById) {
      return matchedById;
    }
  }

  const normalizedCallsign = normalizeCallsign(officer.callsign);
  if (!normalizedCallsign) return null;

  return units.find((unit) => normalizeCallsign(unit?.callsign) === normalizedCallsign) || null;
}
