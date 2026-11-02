#!/bin/bash
# Custom compliance discovery script for Linux (Lab 3.3).
# Runs in the user's context, so it only reads values a standard user can read.
# Output: one JSON object; the keys must match SettingName in etcX-LinuxRules.json.

if systemctl is-active --quiet firewalld; then
  firewall=true
else
  firewall=false
fi

if rpm -q microsoft-edge-stable >/dev/null 2>&1; then
  edge=$(rpm -q --qf '%{VERSION}' microsoft-edge-stable)
else
  edge="0.0"
fi

echo "{\"FirewalldActive\":$firewall,\"EdgeVersion\":\"$edge\"}"
