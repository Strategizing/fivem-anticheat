# NexusGuard - Advanced FiveM Anti-Cheat

NexusGuard is a comprehensive, AI-powered anti-cheat system designed specifically for FiveM servers.

## Features

- **AI-Powered Detection**: Machine learning algorithms to identify unusual player behavior
- **Multi-Layer Protection**: Client-side and server-side verification to catch various cheating methods
- **Performance Optimized**: Minimal impact on server performance
- **Advanced Admin Tools**: Real-time monitoring and notification system
- **Customizable Response**: Configure how the system responds to different types of cheating

## Installation

1. Download the latest release
2. Extract to your server resources folder
3. Add `ensure fivem-anticheat` to your server.cfg
4. Configure `config.lua` to your preferences
5. Restart your server

## Configuration

See `config.lua` for detailed configuration options. Key settings include:

- Detection thresholds
- Action responses
- Discord integration
- Database settings

## Admin Commands

- `/ac ban <id> <reason>` - Ban a player
- `/ac kick <id> <reason>` - Kick a player  
- `/ac check <id>` - Run a comprehensive check on a player
- `/ac history <id>` - View detection history for a player
- `/ac stats` - View anti-cheat statistics

## API Documentation

Developers can integrate with NexusGuard using the provided API:
```lua
exports['fivem-anticheat']:isPlayerFlagged(playerId)
exports['fivem-anticheat']:reportSuspiciousActivity(playerId, reason, evidence)
```

## Support

Join our Discord for support: [discord.gg/nexusguard](https://discord.gg/nexusguard)

## License

All rights reserved. Unauthorized distribution prohibited.
