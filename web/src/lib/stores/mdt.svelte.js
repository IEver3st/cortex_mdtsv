function createMdtStore() {
  let visible = $state(false);
  let loggedIn = $state(false);
  let sessionLoggedIn = $state(false);
  let sidebarCollapsed = $state(false);
  let activePage = $state('dashboard');
  let peeking = $state(false);
  let mode = $state('pd');

  let officer = $state({
    firstName: 'John',
    lastName: 'Doe',
    rank: 'Officer',
    callsign: '1-A-12',
    departmentKey: 'police',
    department: 'Los Santos Police Department',
    departmentShort: 'LSPD',
    avatar: null,
  });

  let civilian = $state({
    firstName: '',
    lastName: '',
    citizenId: null,
  });

  let settings = $state({
    theme: 'default',
    avatarUrl: null,
    callsign: '',
  });

  return {
    get visible() { return visible; },
    set visible(v) { visible = v; },

    get loggedIn() { return loggedIn; },
    set loggedIn(v) { loggedIn = v; },
    get sessionLoggedIn() { return sessionLoggedIn; },
    login() { loggedIn = true; sessionLoggedIn = true; },
    logout() { loggedIn = false; sessionLoggedIn = false; activePage = 'dashboard'; },

    get sidebarCollapsed() { return sidebarCollapsed; },
    set sidebarCollapsed(v) { sidebarCollapsed = v; },
    toggleSidebar() { sidebarCollapsed = !sidebarCollapsed; },

    get activePage() { return activePage; },
    set activePage(v) { activePage = v; },

    get peeking() { return peeking; },
    set peeking(v) { peeking = v; },

    get mode() { return mode; },
    set mode(v) { mode = v; },

    get officer() { return officer; },
    set officer(v) { officer = { ...officer, ...v }; },

    get civilian() { return civilian; },
    set civilian(v) { civilian = { ...civilian, ...v }; },

    get settings() { return settings; },
    set settings(v) { settings = { ...settings, ...v }; },
  };
}

export const mdtStore = createMdtStore();
