# OpenCode Menu Bar Widget

The widget reads ChatGPT subscription quota from a local Playwright helper. It
connects to an already-authenticated Chrome debugging session; it does not
store passwords, cookies, session tokens, or page contents.

## OpenAI quota setup

Install the helper dependencies:

```bash
cd OpenAIQuotaHelper
npm install
npx playwright install chromium
```

Create a separate Chrome profile and launch it with the DevTools Protocol
enabled:

```bash
mkdir -p "$HOME/.local/share/opencode/chatgpt-chrome"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --user-data-dir="$HOME/.local/share/opencode/chatgpt-chrome" \
  --remote-debugging-port=9222
```

Sign into ChatGPT in that browser window. The widget uses the local session
through `http://127.0.0.1:9222` and polls the usage page every 15 minutes.

If the helper is not at the default path, set
`OPENAI_QUOTA_HELPER_PATH` to the absolute path of `OpenAIQuotaHelper/index.mjs`.
Set `CHROME_CDP_URL` if Chrome listens on a different local CDP URL.
