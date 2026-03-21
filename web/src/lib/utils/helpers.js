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
