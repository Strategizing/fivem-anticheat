# NexusGuard - Modular FiveM Anti-Cheat Framework

NexusGuard is a modular, event-driven anti-cheat framework designed for FiveM servers. It provides a core structure and several basic detection modules, intended to be customized and extended by server developers.

**This is an open-source framework, not a plug-and-play solution.** It requires configuration and implementation of server-specific logic (permissions, bans, database integration) to function effectively.

## Features (Core Framework)

*   **Modular Detector System**: Easily enable, disable, or create custom detection modules.
*   **Event-Driven Architecture**: Uses standardized events for communication (via `EventRegistry`).
*   **Client & Server Logic**: Basic separation of client-side checks and server-side validation/actions.
*   **Configuration**: Extensive configuration options via `config.lua`.
*   **Basic Detections Included**: Examples for God Mode, Speed Hack, NoClip, Teleport, Weapon Mods, Resource Monitoring, Menu Keybinds.
*   **Helper Utilities**: Basic logging, ban list management (JSON file), admin notifications.
*   **Discord Integration**: Basic webhook logging and Rich Presence support.

## Dependencies

**Required:**

*   **[oxmysql](https://github.com/overextended/oxmysql)**: Used for database operations if enabled in `config.lua`. (Even if DB is disabled, ensure it's present if other resources need its JSON library).
*   **JSON Library**: A JSON library must be available globally (e.g., `json.encode`, `json.decode`). `oxmysql` typically provides this. If not using `oxmysql`, ensure another resource provides it.
*   **[screenshot-basic](https://github.com/citizenfx/screenshot-basic)**: Required for the screenshot functionality if enabled in `config.lua`.

**Optional:**

*   **`chat` resource**: Required for client-side warnings via `NexusGuard:CheatWarning` event.
*   **Permissions System**: Required for `IsPlayerAdmin` function (used for admin notifications). You need to implement this check based on your server's admin system (e.g., ACE perms, framework groups).
*   **Discord Bot Framework (if using bot commands)**: The Discord bot features in `config.lua` require a separate bot implementation using a library like discordia or discord.js. NexusGuard only provides the configuration structure and basic webhook logging.
*   **`discord_perms` (Optional)**: Listed as an optional dependency in `fxmanifest.lua` - likely intended for Discord role-based permissions if implemented.

## Installation

1.  **Download:** Download the latest release of NexusGuard.
2.  **Extract:** Extract the `NexusGuard` folder into your server's `resources` directory.
3.  **Dependencies:** Ensure all **Required Dependencies** listed above are installed and started *before* NexusGuard.
4.  **Configure `config.lua`:**
    *   Carefully review **all** options in `config.lua`.
    *   **Crucially**, provide necessary URLs, tokens, and IDs (e.g., `DiscordWebhook`, `ScreenCapture.webhookURL`, `Discord.botToken`, `Discord.guildId`, `Discord.RichPresence.AppId`).
    *   Adjust detection thresholds and enable/disable detectors as needed.
5.  **Implement Placeholders:**
    *   **CRITICAL:** The default security functions (`ValidateClientHash`, `GenerateSecurityToken`, `ValidateSecurityToken` in `globals.lua`) are **INSECURE PLACEHOLDERS**. You **MUST** replace them with a robust, server-authoritative implementation suitable for your server environment. Failure to do so leaves your server vulnerable to event spoofing.
    *   Implement the `IsPlayerAdmin(playerId)` function in `globals.lua` (or elsewhere) to check permissions based on your server's admin system.
    *   If using the database features (`Config.Database.enabled = true`), implement the database functions (`StorePlayerBan`, `SavePlayerMetrics`, `CollectPlayerMetrics`, `CleanupDetectionHistory`) in `globals.lua` using `oxmysql` or your preferred library. Create the necessary database tables.
    *   If using AI features, implement the AI functions (`InitializeAIModels`, `ProcessAIVerification`, etc.) in `globals.lua`.
    *   Implement the server-side resource verification logic in the `SYSTEM_RESOURCE_CHECK` event handler in `server_main.lua`.
    *   Implement any desired admin commands (the framework for this is basic in `globals.lua` and requires expansion).
6.  **Server Config:** Add `ensure NexusGuard` to your `server.cfg`, ensuring it starts *after* its dependencies.
7.  **Restart Server:** Restart your FiveM server.

## Configuration Deep Dive

*   **`config.lua`**: Contains all user-configurable settings. Read the comments carefully.
*   **Placeholders**: Functions marked as placeholders (especially security) in `globals.lua` and `server_main.lua` **require your implementation**. The script will likely error or be insecure without them.
*   **Thresholds**: Tune detection thresholds (`Config.Thresholds`) carefully to balance sensitivity and false positives for your server environment.
*   **Detectors**: Enable/disable specific detectors (`Config.Detectors`) based on your needs and server performance.
*   **Actions**: Configure how the system reacts to detections (`Config.Actions`).

## Adding Custom Detectors

1.  Create a new Lua file in `NexusGuard/client/detectors/`.
2.  Follow the structure of `NexusGuard/client/detectors/detector_template.lua`.
3.  Define a unique `DetectorName`.
4.  Implement the `Detector.Check()` function with your detection logic. Use `_G.NexusGuard:ReportCheat(DetectorName, details)` to report violations.
5.  Implement `Detector.Initialize()` if needed (e.g., to read specific config values).
6.  The registration block at the end will automatically register and start your detector if its corresponding key exists and is set to `true` in `Config.Detectors`. Add a new entry for your detector in `config.lua` under `Config.Detectors`.

## Contribution

Contributions are welcome! Please follow these guidelines:

1.  **Fork** the repository.
2.  Create a new **branch** for your feature or bug fix.
3.  Write **clear and concise** code with comments.
4.  Ensure your changes **do not break** existing functionality.
5.  Test your changes thoroughly.
6.  Submit a **Pull Request** with a detailed description of your changes.

## License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.
