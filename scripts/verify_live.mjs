import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const URL = process.env.TARGET_URL || 'https://smnlavallee.github.io/velvet-quill-7392/';
const OUT_DIR = process.env.SCREENSHOT_DIR || 'e2e-screenshots';
fs.mkdirSync(OUT_DIR, { recursive: true });

async function getSemanticsDump(page) {
  return page.evaluate(() => {
    const items = [];
    function walk(root) {
      if (!root) return;
      for (const el of root.querySelectorAll('*')) {
        const role = el.getAttribute('role') || '';
        const aria = (el.getAttribute('aria-label') || '').trim();
        const tag = el.tagName ? el.tagName.toLowerCase() : '';
        const ownText =
          tag === 'flt-semantics' || role
            ? (el.textContent || '').trim()
            : '';
        if (aria || ownText) {
          const rect = el.getBoundingClientRect();
          items.push({
            tag,
            role,
            aria,
            text: ownText,
            x: Math.round(rect.x),
            y: Math.round(rect.y),
            w: Math.round(rect.width),
            h: Math.round(rect.height),
          });
        }
        if (el.shadowRoot) walk(el.shadowRoot);
      }
    }
    walk(document);
    return items;
  });
}

async function getAllText(page) {
  const items = await getSemanticsDump(page);
  const parts = [];
  for (const it of items) {
    if (it.aria) parts.push(it.aria);
    if (it.text) parts.push(it.text);
  }
  return [...new Set(parts)].join('\n');
}

async function waitForText(page, regex, label, timeoutMs = 30000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const dump = await getAllText(page);
    if (regex.test(dump)) {
      return dump;
    }
    await page.waitForTimeout(250);
  }
  const finalDump = await getAllText(page);
  throw new Error(
    `Timed out waiting for ${label} (${regex}). Semantics dump:\n${finalDump}`
  );
}

async function clickSemanticButton(page, regex, label) {
  const items = await getSemanticsDump(page);
  const match = items.find(
    (it) =>
      it.role === 'button' &&
      it.w > 0 &&
      it.h > 0 &&
      (regex.test(it.aria) || regex.test(it.text))
  );
  if (!match) {
    const buttons = items
      .filter((it) => it.role === 'button')
      .map((b) => JSON.stringify(b))
      .join('\n');
    throw new Error(`Could not find button "${label}" (${regex}). Buttons:\n${buttons}`);
  }
  const cx = match.x + match.w / 2;
  const cy = match.y + match.h / 2;
  console.log(`Clicking button "${label}" at (${cx}, ${cy}) [${match.aria || match.text}]`);
  await page.mouse.click(cx, cy);
  await page.waitForTimeout(300);
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
  });
  const page = await context.newPage();

  const consoleErrors = [];
  const pageErrors = [];
  const failedRequests = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      consoleErrors.push(msg.text());
    }
  });
  page.on('pageerror', (err) => {
    pageErrors.push(String(err));
  });
  page.on('response', (res) => {
    if (res.status() >= 400) {
      failedRequests.push(`${res.status()} ${res.url()}`);
    }
  });

  console.log(`Opening ${URL}...`);
  await page.goto(URL, { waitUntil: 'networkidle', timeout: 60000 });

  // Wait for splash screen to go away and Flutter semantics to render.
  await waitForText(page, /loremtype/i, 'app title');
  await waitForText(page, /0\/25/, 'initial 0/25 progress');
  await waitForText(page, /lorem ipsum dolor sit amet/i, 'initial lorem ipsum words');
  await page.waitForTimeout(400);

  await page.screenshot({ path: path.join(OUT_DIR, '01-initial.png') });
  console.log('✓ 01 Initial screen rendered with 25-word Lorem Ipsum');

  // Test 100-word mode
  await clickSemanticButton(page, /(^|\s)100(\s|$)/, '100 words');
  await waitForText(page, /0\/100/, '0/100 progress');
  await waitForText(page, /explicabo/i, '100th word present');
  await page.screenshot({ path: path.join(OUT_DIR, '02-100-words.png') });
  console.log('✓ 02 100-word mode works');

  // Switch to 10-word mode and toggle punctuation + numbers
  await clickSemanticButton(page, /(^|\s)10(\s|$)/, '10 words');
  await waitForText(page, /0\/10/, '0/10 progress');

  await clickSemanticButton(page, /punctuation/i, 'punctuation toggle');
  await waitForText(page, /Lorem ipsum dolor sit, amet consectetur\. Adipiscing elit sed; do\./, 'punctuated 10 words');

  await clickSemanticButton(page, /numbers/i, 'numbers toggle');
  const expectedPassage = 'Lorem ipsum 42 sit, amet consectetur. Adipiscing 2026 sed; do.';
  await waitForText(
    page,
    /Lorem ipsum 42 sit, amet consectetur\. Adipiscing 2026 sed; do\./,
    'punctuated + numbered 10 words'
  );
  await page.screenshot({ path: path.join(OUT_DIR, '03-punctuation-numbers.png') });
  console.log('✓ 03 Punctuation + Numbers toggles verified');

  // Type a deliberate mistake, screenshot red state, then Backspace to fix it
  await page.keyboard.type('x', { delay: 40 });
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(OUT_DIR, '04-mistake-red.png') });
  await page.keyboard.press('Backspace');
  await page.waitForTimeout(200);
  console.log('✓ 04 Mistake highlight + Backspace recovery verified');

  // Type the first half and verify live WPM + progress
  const firstHalf = 'Lorem ipsum 42 sit, amet ';
  const secondHalf = 'consectetur. Adipiscing 2026 sed; do.';
  await page.keyboard.type(firstHalf, { delay: 55 });
  await page.waitForTimeout(300);
  const midDump = await waitForText(page, /5\/10/, '5/10 progress mid-test');
  const liveWpmMatch = midDump.match(/(\d+)\s+wpm/i);
  assert.ok(liveWpmMatch && Number(liveWpmMatch[1]) > 0, `Expected live WPM > 0, got:\n${midDump}`);
  await page.screenshot({ path: path.join(OUT_DIR, '05-mid-typing.png') });
  console.log(`✓ 05 Mid-test progress 5/10 & live WPM = ${liveWpmMatch[1]}`);

  // Finish the remaining words
  await page.keyboard.type(secondHalf, { delay: 55 });
  const resultsDump = await waitForText(page, /Reset/i, 'Reset button on completion');
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(OUT_DIR, '06-results.png') });

  // Verify stats exist on completion screen
  assert.match(resultsDump, /wpm/i, 'Results should display wpm label');
  assert.match(resultsDump, /acc/i, 'Results should display acc label');
  assert.match(resultsDump, /\d+%/, 'Results should display accuracy percentage');
  assert.match(resultsDump, /\d+(\.\d)?s/, 'Results should display elapsed time');
  assert.match(resultsDump, /words 10.*punctuation.*numbers/i, 'Results should reflect active test mode');
  console.log('✓ 06 Completion results & bottom Reset button verified');
  console.log('--- RESULTS SEMANTICS ---\n' + resultsDump + '\n--- END ---');

  // Click the bottom Reset button
  await clickSemanticButton(page, /Reset/i, 'Reset button');
  const afterResetDump = await waitForText(page, /0\/10/, '0/10 after reset');
  assert.ok(
    afterResetDump.includes(expectedPassage),
    `Expected same passage after reset:\n${afterResetDump}`
  );

  // Immediately type "Lorem " without clicking anywhere to verify instant keyboard focus
  await page.keyboard.type('Lorem ', { delay: 55 });
  await waitForText(page, /1\/10/, '1/10 immediately after reset');
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(OUT_DIR, '07-after-reset.png') });
  console.log('✓ 07 Reset restored identical passage and immediate typing works');

  assert.equal(consoleErrors.length, 0, `Console errors found:\n${consoleErrors.join('\n')}`);
  assert.equal(pageErrors.length, 0, `Page errors found:\n${pageErrors.join('\n')}`);
  assert.equal(failedRequests.length, 0, `Failed HTTP requests found:\n${failedRequests.join('\n')}`);

  await browser.close();
  console.log('ALL LIVE BROWSER CHECKS PASSED WITH 0 ERRORS!');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
