/**
 * Quick manual test for the OneSignal push-notification pipeline.
 *
 * Sends a real push through the same path production code uses
 * (`services/push.ts`'s OneSignal REST call), either to:
 *   - every device registered for an account (by email), or
 *   - a single raw OneSignal player id (bypasses the DB entirely).
 *
 * Usage (from apps/backend):
 *   npm run test:push -- --email=someone@example.com
 *   npm run test:push -- --email=someone@example.com --title="Hi" --body="Test push"
 *   npm run test:push -- --token=<onesignal-player-id>
 *
 * Requires ONESIGNAL_APP_ID + ONESIGNAL_REST_API_KEY in apps/backend/.env
 * (same credentials the running server uses).
 */
import 'dotenv/config';
import { prisma } from '../src/services/db.js';

const ONESIGNAL_API_URL = 'https://onesignal.com/api/v1/notifications';

function parseArgs(argv: string[]): Record<string, string> {
  const args: Record<string, string> = {};
  for (const raw of argv) {
    const match = /^--([^=]+)=?(.*)$/.exec(raw);
    if (match) args[match[1]] = match[2] || 'true';
  }
  return args;
}

async function sendToPlayerIds(
  playerIds: string[],
  notification: { title: string; body: string; data?: Record<string, string> },
): Promise<void> {
  const appId = process.env.ONESIGNAL_APP_ID;
  const apiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!appId || !apiKey) {
    console.error(
      '\n✗ ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY are not set in apps/backend/.env\n' +
        '  Get them from https://dashboard.onesignal.com → your app → Keys & IDs.\n',
    );
    process.exit(1);
  }

  const payload = {
    app_id: appId,
    include_player_ids: playerIds,
    headings: { en: notification.title, es: notification.title },
    contents: { en: notification.body, es: notification.body },
    data: notification.data ?? {},
  };

  console.log(`\n→ Sending push to ${playerIds.length} device(s): ${playerIds.join(', ')}`);
  console.log(`  Title: "${notification.title}"  Body: "${notification.body}"\n`);

  const resp = await fetch(ONESIGNAL_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${apiKey}`,
    },
    body: JSON.stringify(payload),
  });
  const json = await resp.json().catch(() => null);

  if (!resp.ok) {
    console.error(`✗ OneSignal rejected the request (HTTP ${resp.status})`);
    console.error(JSON.stringify(json, null, 2));
    process.exit(1);
  }

  const recipients = json?.recipients ?? 0;
  console.log(`✓ OneSignal accepted the request (notification id: ${json?.id})`);
  console.log(`  recipients: ${recipients}`);
  if (recipients === 0) {
    console.warn(
      '\n⚠ OneSignal accepted the request but reports 0 recipients.\n' +
        '  The player id(s) are likely stale/unsubscribed (e.g. app reinstalled,\n' +
        '  notification permission revoked, or running on a simulator).\n' +
        '  Re-open the app on a real device, make sure push permission is granted,\n' +
        '  and re-run this script.\n',
    );
  } else {
    console.log('\nCheck the device now — the notification should arrive within a few seconds.\n');
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const title = args.title ?? 'VerifiA test push';
  const body = args.body ?? 'If you can see this, push notifications are working.';

  if (args.token) {
    await sendToPlayerIds([args.token], { title, body, data: { type: 'test' } });
    return;
  }

  if (!args.email) {
    console.error(
      '\nUsage:\n' +
        '  npm run test:push -- --email=someone@example.com [--title="..."] [--body="..."]\n' +
        '  npm run test:push -- --token=<onesignal-player-id> [--title="..."] [--body="..."]\n',
    );
    process.exit(1);
  }

  const account = await prisma.account.findUnique({
    where: { email: String(args.email).toLowerCase() },
    select: { id: true, email: true, device_tokens: { select: { token: true, platform: true } } },
  });

  if (!account) {
    console.error(`\n✗ No account found for email "${args.email}"`);
    process.exit(1);
  }

  if (account.device_tokens.length === 0) {
    console.error(
      `\n✗ Account "${account.email}" has no registered devices (device_tokens is empty).\n` +
        '  Open the app on a device, log in with this account, grant notification\n' +
        '  permission, and wait a few seconds for it to register — then re-run this script.\n',
    );
    process.exit(1);
  }

  console.log(
    `Found ${account.device_tokens.length} device(s) for ${account.email}: ` +
      account.device_tokens.map((d) => `${d.platform}:${d.token.slice(0, 12)}…`).join(', '),
  );

  await sendToPlayerIds(
    account.device_tokens.map((d) => d.token),
    { title, body, data: { type: 'test' } },
  );
}

main()
  .catch((err) => {
    console.error('\n✗ Unexpected error:', err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
