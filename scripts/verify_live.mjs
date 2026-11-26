import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const URL =
  process.env.TARGET_URL || 'https://smnlavallee.github.io/velvet-quill-7392/';
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
          tag === 'flt-semantics' || role ? (el.textContent || '').trim() : '';
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

async function getCurrentPassage(page) {
  const items = await getSemanticsDump(page);
  for (const it of items) {
    for (const candidate of [it.aria, it.text]) {
      const m = candidate.match(/Typing passage:\s*(.+)/);
      if (m) return m[1].trim();
    }
  }
  return null;
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

async function findInteractive(page, regex, label) {
  const items = await getSemanticsDump(page);
  const match = items.find(
    (it) =>
      (it.role === 'button' || it.role === 'menuitem') &&
      it.w > 0 &&
      it.h > 0 &&
      (regex.test(it.aria) || regex.test(it.text))
  );
  if (!match) {
    const controls = items
      .filter((it) => it.role === 'button' || it.role === 'menuitem')
      .map((b) => JSON.stringify(b))
      .join('\n');
    throw new Error(
      `Could not find control "${label}" (${regex}). Controls:\n${controls}`
    );
  }
  return match;
}

async function clickControl(page, regex, label) {
  const match = await findInteractive(page, regex, label);
  const cx = match.x + match.w / 2;
  const cy = match.y + match.h / 2;
  console.log(
    `Clicking "${label}" at (${cx}, ${cy}) [${match.aria || match.text}]`
  );
  await page.mouse.click(cx, cy);
  await page.waitForTimeout(350);
  return match;
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

  await waitForText(page, /loremtype/i, 'app title');
  await waitForText(page, /0\/25/, 'initial 0/25 progress');
  await waitForText(page, /Language:\s*English/i, 'English language selector');
  await page.waitForTimeout(400);

  // Verify language dropdown sits to the right of the 100 word button on the same row.
  const btn100 = await findInteractive(page, /(^|\s)100(\s|$)/, '100 words');
  const langBtn = await findInteractive(
    page,
    /Language:\s*English/i,
    'language dropdown'
  );
  assert.ok(
    langBtn.x > btn100.x + btn100.w,
    `Expected language dropdown (x=${langBtn.x}) to the right of 100 button (right=${btn100.x + btn100.w})`
  );
  assert.ok(
    Math.abs(langBtn.y + langBtn.h / 2 - (btn100.y + btn100.h / 2)) <= 12,
    `Expected language dropdown aligned on same top row as 100 button`
  );

  await page.screenshot({ path: path.join(OUT_DIR, '01-initial-english.png') });
  console.log('✓ 01 Initial English screen & separate top-right language box verified');

  // Test 100-word mode reshuffling on Esc restart
  await clickControl(page, /(^|\s)100(\s|$)/, '100 words');
  await waitForText(page, /0\/100/, '0/100 progress');
  const hundredRun1 = await getCurrentPassage(page);
  assert.ok(hundredRun1 && hundredRun1.split(/\s+/).length === 100, 'Expected 100 words');

  await page.keyboard.press('Escape');
  await page.waitForTimeout(350);
  const hundredRun2 = await getCurrentPassage(page);
  assert.ok(hundredRun2 && hundredRun2.split(/\s+/).length === 100, 'Expected 100 words after Esc');
  assert.notEqual(
    hundredRun2,
    hundredRun1,
    '100-word sequence must change order on restart'
  );
  await page.screenshot({ path: path.join(OUT_DIR, '02-100-words-reshuffled.png') });
  console.log('✓ 02 100-word reshuffle on restart verified');

  // Open language dropdown and switch to French
  await clickControl(page, /Language:\s*English/i, 'open language dropdown');
  await waitForText(page, /French/, 'French menu option');
  await waitForText(page, /Lorem Ipsum/, 'Lorem Ipsum menu option');
  await page.screenshot({ path: path.join(OUT_DIR, '03-dropdown-open.png') });

  await clickControl(page, /^French$/, 'select French');
  await waitForText(page, /Language:\s*French/i, 'French active');
  const frenchPassage = await getCurrentPassage(page);
  assert.ok(frenchPassage && frenchPassage.split(/\s+/).length === 100, 'Expected 100 French words');
  assert.notEqual(frenchPassage, hundredRun2, 'French passage should differ from English');
  await page.screenshot({ path: path.join(OUT_DIR, '04-french.png') });
  console.log('✓ 04 French language switch verified');

  // Switch to Lorem Ipsum
  await clickControl(page, /Language:\s*French/i, 'open language dropdown');
  await clickControl(page, /^Lorem Ipsum$/, 'select Lorem Ipsum');
  await waitForText(page, /Language:\s*Lorem Ipsum/i, 'Lorem Ipsum active');
  const loremPassage = await getCurrentPassage(page);
  assert.ok(loremPassage && /lorem|ipsum|dolor|consectetur/i.test(loremPassage), 'Expected Lorem Ipsum words');
  await page.screenshot({ path: path.join(OUT_DIR, '05-lorem-ipsum.png') });
  console.log('✓ 05 Lorem Ipsum language switch verified');

  // Switch back to English, set 10 words + punctuation + numbers, type through to completion
  await clickControl(page, /Language:\s*Lorem Ipsum/i, 'open language dropdown');
  await clickControl(page, /^English$/, 'select English');
  await waitForText(page, /Language:\s*English/i, 'English active');

  await clickControl(page, /(^|\s)10(\s|$)/, '10 words');
  await waitForText(page, /0\/10/, '0/10 progress');
  await clickControl(page, /punctuation/i, 'punctuation toggle');
  await clickControl(page, /numbers/i, 'numbers toggle');
  await page.waitForTimeout(300);

  const runPassage = await getCurrentPassage(page);
  assert.ok(runPassage, 'Expected active 10-word passage');
  const runWords = runPassage.split(/\s+/);
  assert.equal(runWords.length, 10, `Expected 10 words, got: ${runPassage}`);
  assert.match(runPassage, /\d/, 'Expected numbers in passage');
  assert.match(runPassage, /[.,;:?!"]/, 'Expected punctuation in passage');
  console.log(`Active 10-word passage: "${runPassage}"`);

  // Deliberate mistake + backspace
  const wrongKey = runWords[0].startsWith('Z') ? 'Q' : 'Z';
  await page.keyboard.type(wrongKey, { delay: 40 });
  await page.waitForTimeout(200);
  await page.keyboard.press('Backspace');
  await page.waitForTimeout(200);

  // Type first 5 words and check live WPM
  const firstHalf = runWords.slice(0, 5).join(' ') + ' ';
  const secondHalf = runWords.slice(5).join(' ');
  await page.keyboard.type(firstHalf, { delay: 50 });
  await page.waitForTimeout(300);
  const midDump = await waitForText(page, /5\/10/, '5/10 progress mid-test');
  const liveWpmMatch = midDump.match(/(\d+)\s+wpm/i);
  assert.ok(
    liveWpmMatch && Number(liveWpmMatch[1]) > 0,
    `Expected live WPM > 0, got:\n${midDump}`
  );
  await page.screenshot({ path: path.join(OUT_DIR, '06-mid-typing.png') });
  console.log(`✓ 06 Mid-typing 5/10 & live WPM = ${liveWpmMatch[1]}`);

  // Finish remaining 5 words
  await page.keyboard.type(secondHalf, { delay: 50 });
  const resultsDump = await waitForText(page, /Reset/i, 'Reset button on completion');
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(OUT_DIR, '07-results.png') });

  assert.match(resultsDump, /wpm/i, 'Results should display wpm');
  assert.match(resultsDump, /\d+%/, 'Results should display accuracy %');
  assert.match(resultsDump, /words 10.*english.*punctuation.*numbers/i, 'Results should show test mode & language');
  console.log('✓ 07 Completion results & bottom Reset button verified');

  // Click Reset and verify NEW sequence appears and immediate typing works
  await clickControl(page, /Reset/i, 'Reset button');
  await waitForText(page, /0\/10/, '0/10 after reset');
  const afterResetPassage = await getCurrentPassage(page);
  assert.ok(afterResetPassage, 'Expected new passage after reset');
  assert.notEqual(
    afterResetPassage,
    runPassage,
    'Reset must generate a fresh randomized word sequence'
  );
  const firstNewWord = afterResetPassage.split(/\s+/)[0];
  await page.keyboard.type(`${firstNewWord} `, { delay: 50 });
  await waitForText(page, /1\/10/, '1/10 immediately after reset');
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(OUT_DIR, '08-after-reset.png') });
  console.log('✓ 08 Reset produced a brand-new sequence and accepted immediate typing');

  assert.equal(consoleErrors.length, 0, `Console errors:\n${consoleErrors.join('\n')}`);
  assert.equal(pageErrors.length, 0, `Page errors:\n${pageErrors.join('\n')}`);
  assert.equal(failedRequests.length, 0, `Failed HTTP requests:\n${failedRequests.join('\n')}`);

  await browser.close();
  console.log('ALL LIVE BROWSER CHECKS PASSED WITH 0 ERRORS!');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
