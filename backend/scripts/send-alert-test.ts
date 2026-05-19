/**
 * Sends `✅ LinkClip alert test` to Slack when ALERTS_ENABLED / webhook env are set.
 * Run from repo root: cd backend && npm run diag:alert
 * Never prints webhook URLs or tokens.
 */
import "dotenv/config";

import { sendOperationalAlertTestPing } from "../src/services/alert.service";

void sendOperationalAlertTestPing().then((ok) => {
  process.exit(ok ? 0 : 1);
});
