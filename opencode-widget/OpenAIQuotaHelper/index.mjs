import { chromium } from "playwright";

const usageURL = process.env.OPENAI_USAGE_URL;
const cdpURL = process.env.CHROME_CDP_URL || "http://127.0.0.1:9222";

if (!usageURL) {
  process.exit(1);
}

let browser;
try {
  browser = await chromium.connectOverCDP(cdpURL);
  const pages = browser.contexts().flatMap((context) => context.pages());
  const page = pages[0] || await browser.contexts()[0]?.newPage();
  if (!page) process.exit(1);

  await page.goto(usageURL, { waitUntil: "domcontentloaded", timeout: 10_000 });
  const text = await page.locator("body").innerText({ timeout: 5_000 });
  if (/sign\s*in|log\s*in/i.test(text) && !/remaining|reset/i.test(text)) {
    process.exit(1);
  }

  const percentMatch = text.match(/(\d{1,3}(?:\.\d+)?)\s*%\s*(?:remaining|left)?/i);
  const remainingPercent = percentMatch ? Number(percentMatch[1]) : null;
  if (remainingPercent === null || remainingPercent < 0 || remainingPercent > 100) {
    process.exit(1);
  }

  const resetMatch = text.match(/(?:reset(?:s|ting)?|renews?|next reset)[^\n]{0,40}?\b((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2})\b/i);
  let resetDate = null;
  if (resetMatch) {
    const parsed = new Date(`${resetMatch[1]}, ${new Date().getFullYear()}`);
    if (!Number.isNaN(parsed.valueOf())) resetDate = parsed.toISOString();
  }

  process.stdout.write(JSON.stringify({ remainingPercent, resetDate }));
} catch {
  process.exitCode = 1;
} finally {
  // Disconnect only; the authenticated browser remains open for the user.
  browser?.disconnect();
}
