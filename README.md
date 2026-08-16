# opencode-deepseek-minimax-macwidget

macOS menu bar app that tracks DeepSeek and MiniMax API usage in real time. Shows balance, credit, and token usage at a glance.

## Credits

- **minimax-usage-checker** by [AungMyoKyaw](https://github.com/AungMyoKyaw/minimax-usage-checker) — original inspiration and reference implementation
- **Lobe Icons** by [lobehub](https://github.com/lobehub/lobe-icons) — DeepSeek and MiniMax brand icons

## Features

- Menu bar icons showing DeepSeek and MiniMax balances
- Auto-fetches from DeepSeek balance API and MiniMax credit API
- Manual credit entry with save/cancel
- 15-minute auto-refresh
- B&W monochrome design

## Example

### DeepSeek + MiniMax

The original version keeps both providers visible in a compact menu-bar panel. Each card shows the provider balance and status at a glance, while the Refresh and Quit actions remain available below the cards.

![DeepSeek and MiniMax macOS menu bar widget](https://i.postimg.cc/ncKXx3fs/widget.png)

*Example of the DeepSeek + MiniMax widget layout.*

### DeepSeek + MiniMax + ChatGPT Plus

The expanded version adds a ChatGPT Plus quota card below the DeepSeek and MiniMax balances. It shows the remaining subscription percentage and the next quota reset date in the same compact menu-bar panel.

![DeepSeek, MiniMax, and ChatGPT Plus macOS menu bar widget](https://i.postimg.cc/76TLWVN8/Screenshot-2026-07-16-at-9-34-59-PM.png)

*Example of the DeepSeek + MiniMax + ChatGPT Plus widget layout.*

### Latest Iteration: 168-Hour Usage Chart

The current widget adds a 168-hour smoothed input-token chart directly below
the OpenAI quota card. It shows OpenAI in green and DeepSeek in blue, with
calendar dates and month labels on the x-axis.

![OpenCode widget with OpenAI and DeepSeek 168-hour usage chart](https://i.postimg.cc/PfvC4qr2/Screenshot-2026-08-16-at-11-02-16-PM.png)

*Latest iteration with OpenAI quota, provider balances, and the two-line usage chart.*

## API Approach

### DeepSeek — `/user/balance`

```
GET https://api.deepseek.com/user/balance
Authorization: Bearer <api-key>
```

Returns `balance_infos[].total_balance` as a USD string. This is a public, undocumented endpoint used by the DeepSeek web console. Works with any valid API key.

### MiniMax — `/account/query_balance`

```
GET https://platform.minimax.io/account/query_balance
Authorization: Bearer <api-key>
```

Returns `available_amount` as a USD string. This is the web console's internal balance API. Unlike the documented `/coding_plan/remains` (prompt counts), this returns actual dollar credit. Works with the same API key used for chat/completion.

Both endpoints were discovered by inspecting network requests from their respective web consoles. Neither is documented in official API references.

### Auth

API keys are read from OpenCode's auth config at `~/.local/share/opencode/auth.json`:

```json
{
  "deepseek": {"type": "api", "key": "sk-..."},
  "minimax": {"type": "api", "key": "sk-..."}
}
```

## Build

```bash
cd opencode-widget
xcodegen generate
xcodebuild -scheme OpencodeWidgetApp -configuration Debug build
```

Requires macOS 14+ and Xcode 16+.
