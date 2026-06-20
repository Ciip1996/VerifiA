import OneSignal from 'react-onesignal';

const APP_ID = import.meta.env.VITE_ONESIGNAL_APP_ID as string | undefined;
const BASE_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3001';

let _initialized = false;

// ─── Token registration helpers ───────────────────────────────────────────────

async function registerToken(token: string, sessionToken: string): Promise<void> {
  await fetch(`${BASE_URL}/api/v1/devices/register`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${sessionToken}`,
    },
    body: JSON.stringify({ token, platform: 'web' }),
  });
}

async function unregisterToken(token: string, sessionToken: string): Promise<void> {
  await fetch(`${BASE_URL}/api/v1/devices/unregister`, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${sessionToken}`,
    },
    body: JSON.stringify({ token }),
  });
}

// ─── Initialization ───────────────────────────────────────────────────────────

/**
 * Initializes the OneSignal Web SDK. Safe to call multiple times (no-op after first call).
 * Should be called once on app startup, before login.
 * Push permission is NOT requested here — call `requestPermission` separately after user consent.
 */
export async function initOneSignal(): Promise<void> {
  if (_initialized || !APP_ID) return;
  _initialized = true;

  try {
    await OneSignal.init({
      appId: APP_ID,
      // Allow localhost without HTTPS for dev
      allowLocalhostAsSecureOrigin: true,
      // Don't auto-prompt for permission; we control when to ask
      promptOptions: {
        slidedown: { prompts: [] },
      },
    });
  } catch (err) {
    console.warn('[onesignal] init failed:', err);
    _initialized = false;
  }
}

/**
 * Links this browser subscription to the authenticated account
 * and registers the token with the VerifiA backend.
 *
 * Call after a successful login with the account ID and session token.
 */
export async function loginOneSignal(
  accountId: string,
  sessionToken: string,
): Promise<void> {
  if (!APP_ID) return;
  try {
    // Associate the subscription with this account for targeted push delivery
    await OneSignal.login(accountId);

    // Persist token with backend so push.ts can reach this browser
    const token = OneSignal.User.PushSubscription.token;
    if (token) {
      await registerToken(token, sessionToken).catch((e) =>
        console.warn('[onesignal] registerToken failed:', e),
      );
    }

    // Also register when the subscription is assigned after permission is granted
    OneSignal.User.PushSubscription.addEventListener('change', (event) => {
      const newToken = event.current.token;
      if (newToken) {
        void registerToken(newToken, sessionToken).catch((e) =>
          console.warn('[onesignal] registerToken (change) failed:', e),
        );
      }
    });
  } catch (err) {
    console.warn('[onesignal] login failed:', err);
  }
}

/**
 * Disassociates the browser subscription from the account on logout.
 * Unregisters the token from the VerifiA backend so the device stops receiving pushes.
 */
export async function logoutOneSignal(sessionToken: string): Promise<void> {
  if (!APP_ID) return;
  try {
    const token = OneSignal.User.PushSubscription.token;
    if (token) {
      await unregisterToken(token, sessionToken).catch((e) =>
        console.warn('[onesignal] unregisterToken failed:', e),
      );
    }
    await OneSignal.logout();
  } catch (err) {
    console.warn('[onesignal] logout failed:', err);
  }
}

/**
 * Requests browser push permission with a soft prompt.
 * Call this from a UI interaction (button click) — never automatically.
 */
export async function requestPushPermission(): Promise<void> {
  if (!APP_ID) return;
  try {
    await OneSignal.Notifications.requestPermission();
  } catch (err) {
    console.warn('[onesignal] requestPermission failed:', err);
  }
}

/**
 * Returns whether the user has already granted push permission.
 */
export function hasPushPermission(): boolean {
  if (!APP_ID) return false;
  return OneSignal.Notifications.permission;
}

/**
 * Returns whether OneSignal is configured in this build (APP_ID is set).
 */
export function isOneSignalConfigured(): boolean {
  return Boolean(APP_ID);
}
