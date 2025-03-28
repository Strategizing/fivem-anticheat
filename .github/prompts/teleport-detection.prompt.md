# Teleport Detection Prompt

## Purpose
- Identify large, unexplained position deltas.
- Check time/distance calculations to confirm legitimate travel.
- Handle edge cases (e.g., server join, respawn events).

## Key Points
- Use last known position to calculate sudden shifts.
- Apply a small grace zone for normal short-distance position corrections.

