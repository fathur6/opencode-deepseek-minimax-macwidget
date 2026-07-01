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

## Build

```bash
cd opencode-widget
xcodegen generate
xcodebuild -scheme OpencodeWidgetApp -configuration Debug build
```

Requires macOS 14+ and Xcode 16+.
