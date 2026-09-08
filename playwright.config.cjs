const fs = require('node:fs');
const path = require('node:path');
const { defineConfig } = require('@playwright/test');

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return;
  }

  for (const rawLine of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();

    if (!line || line.startsWith('#')) {
      continue;
    }

    const separator = line.indexOf('=');
    if (separator < 1) {
      continue;
    }

    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();

    if (
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")))
    ) {
      value = value.slice(1, -1);
    }

    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}

loadEnvFile(path.join(__dirname, '.env'));

const wpHost = process.env.WP_HOST || 'wp-site-options.local';
const wpPort = process.env.WP_HTTP_PORT || '8088';

if (!/^\d+$/.test(wpPort) || Number(wpPort) < 1 || Number(wpPort) > 65535) {
  throw new Error('WP_HTTP_PORT must be an integer from 1 to 65535.');
}

module.exports = defineConfig({
  testDir: './tests/e2e',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 30_000,
  expect: {
    timeout: 5_000,
  },
  outputDir: 'test-results/e2e',
  preserveOutput: 'failures-only',
  reporter: 'line',
  use: {
    baseURL: `http://${wpHost}${wpPort === '80' ? '' : `:${wpPort}`}`,
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    video: 'off',
    launchOptions: {
      args: [`--host-resolver-rules=MAP ${wpHost} 127.0.0.1`],
    },
  },
});
