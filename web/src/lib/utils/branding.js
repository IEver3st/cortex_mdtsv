const lspdLogo = `${import.meta.env.BASE_URL}lspd-logo.webp`;
const citySeal = `${import.meta.env.BASE_URL}LosSantosSeal.webp`;

function normalizeDepartmentKey({ departmentKey, department, departmentShort }) {
  const key = (departmentKey || '').trim().toLowerCase();

  if (key) return key;

  const short = (departmentShort || '').trim().toLowerCase();
  const label = (department || '').trim().toLowerCase();

  if (short === 'lspd' || label.includes('police')) {
    return 'police';
  }

  if (short === 'civ' || label.includes('civilian') || label.includes('citizen')) {
    return 'civilian';
  }

  return '';
}

export function getDepartmentBrand(context = {}) {
  const key = normalizeDepartmentKey(context);

  if (key === 'police' || key === 'lspd') {
    return {
      key: 'police',
      src: lspdLogo,
      alt: 'Los Santos Police Department logo',
      variant: 'logo',
    };
  }

  return {
    key: key || 'civilian',
    src: citySeal,
    alt: 'Los Santos city seal',
    variant: 'seal',
  };
}
