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
account in Codex. The client classifies both returned windows by their
`limit_window_seconds` duration (`18000` = 5-hour, `604800` = weekly) rather
than by position, so it still works when the payload only carries one window
or reverses `primary_window`/`secondary_window`. A missing or malformed window
does not hide the other, and a failed refresh keeps the last known value for
each window independently.
