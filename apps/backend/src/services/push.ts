import { prisma } from './db.js';

const ONESIGNAL_API_URL = 'https://onesignal.com/api/v1/notifications';

function getCredentials(): { appId: string; apiKey: string } | null {
  const appId = process.env.ONESIGNAL_APP_ID;
  const apiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!appId || !apiKey) return null;
  return { appId, apiKey };
}

/**
 * Sends a push notification to all registered devices for a given account.
 * Silently no-ops if OneSignal is not configured or the account has no tokens.
 */
export async function pushToAccount(
  accountId: string,
  notification: { title: string; body: string; data?: Record<string, string> },
): Promise<void> {
  const creds = getCredentials();
  if (!creds) return; // OneSignal not configured — skip silently

  const rows = await prisma.deviceToken.findMany({
    where: { account_id: accountId },
    select: { token: true },
  });
  if (rows.length === 0) return;

  const subscriptionIds = rows.map((r) => r.token);

  const payload = {
    app_id: creds.appId,
    include_subscription_ids: subscriptionIds,
    headings: { en: notification.title, es: notification.title },
    contents: { en: notification.body, es: notification.body },
    data: notification.data ?? {},
  };

  try {
    const resp = await fetch(ONESIGNAL_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${creds.apiKey}`,
      },
      body: JSON.stringify(payload),
    });
    if (!resp.ok) {
      const text = await resp.text();
      console.warn('[push] OneSignal error', resp.status, text);
    }
  } catch (err) {
    // Push is best-effort — never fail the main request
    console.warn('[push] Failed to send push notification:', err);
  }
}

/**
 * Sends a push to the account identified by email.
 * Used when we only have the target_email (e.g. cancel notification to recipient).
 */
export async function pushToEmail(
  email: string,
  notification: { title: string; body: string; data?: Record<string, string> },
): Promise<void> {
  const account = await prisma.account.findUnique({
    where: { email: email.toLowerCase() },
    select: { id: true },
  });
  if (!account) return;
  await pushToAccount(account.id, notification);
}
