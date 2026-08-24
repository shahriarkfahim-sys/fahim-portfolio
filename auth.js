const AUTH_KEY = 'fahim-dashboard-auth';
const DEMO_CREDENTIALS = {
  username: 'fahim',
  password: 'Fahim@2026!'
};

function isDashboardAuthenticated() {
  return sessionStorage.getItem(AUTH_KEY) === 'signed-in';
}

function requireDashboardAuth() {
  if (!isDashboardAuthenticated()) {
    window.location.replace('/login.html');
  }
}

function signOut() {
  sessionStorage.removeItem(AUTH_KEY);
  window.location.replace('/login.html');
}

function setupLoginForm() {
  const form = document.getElementById('loginForm');
  const error = document.getElementById('loginError');

  if (!form) return;
  if (isDashboardAuthenticated()) {
    window.location.replace('/dashboard');
    return;
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault();
    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value;

    if (username === DEMO_CREDENTIALS.username && password === DEMO_CREDENTIALS.password) {
      sessionStorage.setItem(AUTH_KEY, 'signed-in');
      window.location.replace('/dashboard');
      return;
    }

    error.hidden = false;
    error.textContent = 'That username or password is not correct.';
  });
}
