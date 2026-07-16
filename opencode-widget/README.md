# OpenCode Menu Bar Widget

The widget reads ChatGPT/Codex subscription quota from the OAuth session used
by Codex. It calls the authenticated `/backend-api/wham/usage` endpoint and
does not store passwords, cookies, session tokens, or response bodies.

## OpenAI quota setup

Sign in with Codex so that `~/.codex/auth.json` contains the OAuth session.
The widget polls `https://chatgpt.com/backend-api/wham/usage` every 15 minutes
using the access token and optional account ID from that file. Tokens are only
held in memory while the request is made; they are not logged or copied into
the widget cache.

If the response is `401`, re-authenticate or switch to the intended ChatGPT
account in Codex. The client prefers the weekly `secondary_window` and falls
back to `primary_window` when necessary.
