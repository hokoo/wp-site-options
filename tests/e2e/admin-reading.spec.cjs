const { test, expect } = require('@playwright/test');

const adminUser = process.env.WP_ADMIN_USER || 'admin';
const adminPassword = process.env.WP_ADMIN_PASSWORD || 'admin-local';
const wpHost = process.env.WP_HOST || 'wp-site-options.local';

test('admin can update and persist the representative Reading Settings fields', async ({ context, page }) => {
  const runtimeErrors = [];

  await context.route('**/*', async (route) => {
    const url = new URL(route.request().url());

    if (url.hostname === wpHost || ['about:', 'blob:', 'data:'].includes(url.protocol)) {
      await route.continue();
      return;
    }

    await route.fulfill({ status: 204, body: '' });
  });

  page.on('console', (message) => {
    if (message.type() === 'error') {
      runtimeErrors.push(`console: ${message.text()}`);
    }
  });
  page.on('pageerror', (error) => {
    runtimeErrors.push(`page: ${error.message}`);
  });

  await page.goto('/wp-login.php');
  await page.locator('#user_login').fill(adminUser);
  await page.locator('#user_pass').fill(adminPassword);
  await Promise.all([
    page.waitForURL((url) => url.pathname.startsWith('/wp-admin/')),
    page.locator('#wp-submit').click(),
  ]);

  await page.goto('/wp-admin/options-reading.php');

  const headline = page.locator('#local_fixture-headline');
  const featured = page.locator('#local_fixture-featured');
  const itemsPerPage = page.locator('#local_fixture-items_per_page');

  await expect(page.getByRole('heading', { name: 'Local development options' })).toBeVisible();
  await expect(headline).toBeVisible();
  await expect(featured).toBeVisible();
  await expect(itemsPerPage).toBeVisible();

  await headline.fill('Authenticated browser smoke');
  await featured.check();
  await itemsPerPage.fill('17');

  await Promise.all([
    page.waitForURL((url) => url.pathname === '/wp-admin/options-reading.php' && url.searchParams.has('settings-updated')),
    page.locator('#submit').click(),
  ]);

  await expect(page.locator('#setting-error-settings_updated')).toBeVisible();
  await page.reload();

  await expect(headline).toHaveValue('Authenticated browser smoke');
  await expect(featured).toBeChecked();
  await expect(itemsPerPage).toHaveValue('17');

  const bodyText = await page.locator('body').innerText();
  const visiblePhpErrors =
    bodyText.match(/\b(?:Fatal error|Parse error|Warning|Notice|Deprecated):[^\n]*/gi) || [];
  const diagnostics = [
    ...runtimeErrors,
    ...visiblePhpErrors.map((message) => `php: ${message.trim()}`),
  ];

  if (bodyText.includes('There has been a critical error')) {
    diagnostics.push('php: WordPress displayed its critical error screen.');
  }

  expect(diagnostics, diagnostics.join('\n')).toEqual([]);
});
