#!/bin/bash
cp Resources/LaunchAgent.plist ~/Library/LaunchAgents/com.opencode.widget.agent.plist
launchctl load ~/Library/LaunchAgents/com.opencode.widget.agent.plist
echo "LaunchAgent installed and loaded."
