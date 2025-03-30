# NexusGuard - Modular FiveM Anti-Cheat Framework (v0.6.9)

NexusGuard is a modular, event-driven anti-cheat framework designed for FiveM servers. It provides a core structure and several basic detection modules, intended to be customized and extended by server developers.

**⚠️ This is an open-source framework, not a plug-and-play solution. ⚠️** It requires careful configuration and **significant implementation** of server-specific logic (permissions, bans, database integration, **critical security measures**) to function effectively and securely. **Do not deploy this on a live server without addressing the security placeholders.**

## Features (Core Framework)

*   **Modular Detector System**: Easily enable, disable, or create custom detection modules (`client/detectors/`).
*   **Event-Driven Architecture**: Uses standardized events for communication (via `shared/EventRegistry.lua`).
*   **Client & Server Logic**: Basic separation of client-side checks and server-side validation/actions.
*   **Configuration**: Extensive configuration options via `config.lua`.
*   **Basic Detections Included**: Examples for God Mode, Speed Hack, NoClip, Teleport, Weapon Mods, Resource Monitoring, Menu Keybinds.
*   **Helper Utilities**: Basic logging, database-driven ban system (requires setup), admin notifications.
*   **Discord Integration**: Basic webhook logging and Rich Presence support.
*   **Database Support**: Includes schema (`sql/schema.sql`) for storing bans, detections, and session summaries using `oxmysql`.

## Dependencies

**Required:**

*   **[oxmysql](https://github.com/overextended/oxmysql)**: Required for database features (bans, detections, sessions) if `Config.Database.enabled = true`. Also provides the necessary JSON library. **Must be started before NexusGuard.**
*   **[screenshot-basic](https://github.com/citizenfx/screenshot-basic)**: Required for the screenshot functionality if `Config.ScreenCapture.enabled = true`. **Must be started before NexusGuard.**

**Optional:**

*   **`chat` resource**: Recommended for displaying client-side warnings via the `NexusGuard:CheatWarning` event. If not used, warnings will only appear in the F8 console.
*   **Permissions System Integration**: You **must** implement the logic within the `IsPlayerAdmin` function in `globals.lua` to correctly check permissions based on your server's admin system (e.g., FiveM ACE perms, ESX/QBCore framework groups/permissions). The default implementation only checks ACE perms listed in `Config.AdminGroups`.
*   **External Discord Bot**: If using advanced Discord bot features (commands, player reports beyond webhooks) defined in `config.lua`, a separate bot implementation (e.g., using discord.js, discord.py, etc.) interacting with NexusGuard (potentially via custom events or API calls) is required. This framework only provides basic webhook logging and Rich Presence.

## Installation

1.  **Download:** Download the latest release (v0.6.9) of NexusGuard.
2.  **Extract:** Extract the `NexusGuard` folder into your server's `resources` directory.
3.  **Dependencies:** Ensure **oxmysql** and **screenshot-basic** are installed and listed in your `server.cfg` to start *before* NexusGuard. Install optional dependencies as needed.
4.  **Database Setup:**
    *   Ensure you have a MySQL database server accessible by your FiveM server.
    *   Import the `NexusGuard/sql/schema.sql` file into your database. This will create the necessary tables (`nexusguard_bans`, `nexusguard_detections`, `nexusguard_sessions`).
    *   Ensure your `oxmysql` resource is correctly configured to connect to your database.
5.  **Configure `config.lua`:**
    *   Carefully review **all** options in `config.lua`.
    *   Carefully review **all** options in `config.lua`. Pay close attention to comments indicating required fields or critical settings.
    *   **CRITICAL:** Set `Config.SecuritySecret` to a **long, unique, and random string**. This secret is intended for use with a **secure token implementation** (see Step 6). **Do not leave the default value.**
    *   Fill in required URLs/IDs if features are enabled: `Config.DiscordWebhook` (for general logs), specific webhook URLs in `Config.Discord.webhooks` (optional), `Config.ScreenCapture.webhookURL`, `Config.Discord.RichPresence.AppId`.
    *   Configure `Config.AdminGroups` to match your server's ACE permission groups for admins if you rely on the default `IsPlayerAdmin` logic.
    *   If enabling `Config.Features.resourceVerification`, carefully configure the `whitelist` or `blacklist`. **Whitelist mode requires adding ALL essential server resources (framework, maps, scripts) to prevent false kicks/bans.** See comments in `config.lua`.
    *   Adjust detection thresholds (`Config.Thresholds`) and enable/disable detectors (`Config.Detectors`) based on testing and server needs.
6.  **Implement Critical Placeholders:**
    *   **(MANDATORY) Security Implementation (`globals.lua`):**
        *   The default security functions (`ValidateClientHash`, `GenerateSecurityToken`, `ValidateSecurityToken`, `PseudoHmac`) are **HIGHLY INSECURE PLACEHOLDERS**. They offer **NO REAL PROTECTION** against event spoofing.
        *   You **MUST** replace the logic within `GenerateSecurityToken` and `ValidateSecurityToken` with a robust, server-authoritative implementation.
        *   **Recommended Approaches:**
            *   **HMAC-SHA256 Signing:** Use `Config.SecuritySecret` with a proper Lua crypto library (e.g., `lua-lockbox`, potentially `ox_lib` functions if available) to sign/verify data in events.
            *   **Secure Session Tokens:** Generate secure random tokens server-side, associate them with player sessions, and validate them.
            *   **Framework Secure Events:** Leverage built-in secure event systems if your framework provides them.
        *   **Failure to replace these placeholders WILL leave your server extremely vulnerable.** See the large warning block in `globals.lua`.
    *   **(MANDATORY) Admin Permission Check (`globals.lua`):**
        *   Implement the `IsPlayerAdmin(playerId)` function to accurately check permissions based on **your specific server's setup** (ACE perms, ESX groups, QBCore permissions/jobs, etc.). The provided examples need uncommenting and adaptation.
    *   **(Optional) Resource Verification Logic (`server_main.lua`):**
        *   If you enable `Config.Features.resourceVerification.enabled = true`, you **MUST** implement the actual resource list comparison logic within the `SYSTEM_RESOURCE_CHECK` event handler in `server_main.lua`. The current code only contains comments and a warning log.
    *   **(Optional) AI & Other Placeholders:** Review other functions marked as placeholders (AI functions, `HandleEntityCreation`) and implement them if you intend to use those features.
7.  **Server Config:** Add `ensure NexusGuard` to your `server.cfg`, ensuring it starts *after* its dependencies (`oxmysql`, `screenshot-basic`).
8.  **Restart Server & Test:** Restart your FiveM server. Check the console thoroughly for any NexusGuard errors or warnings (especially critical ones about missing functions or security). Test detections and actions rigorously.

## Configuration Deep Dive

*   **`config.lua`**: Contains all user-configurable settings. Read the comments carefully.
*   **`Config.SecuritySecret`**: **MUST BE CHANGED** to a strong, unique secret **AND USED IN A SECURE TOKEN IMPLEMENTATION**.
*   **Security Placeholders**: The functions `GenerateSecurityToken` and `ValidateSecurityToken` in `globals.lua` **MUST BE REPLACED** with a secure implementation. The default is **NOT SECURE**.
*   **`IsPlayerAdmin`**: This function in `globals.lua` **MUST BE IMPLEMENTED** correctly for your server's permission system.
*   **Resource Verification**: If enabled, the logic in `server_main.lua` **MUST BE IMPLEMENTED**. Use with caution, especially whitelist mode.
*   **Thresholds**: Tune detection thresholds (`Config.Thresholds`) carefully through testing.
*   **Detectors**: Enable/disable specific detectors (`Config.Detectors`).
*   **Actions**: Configure reactions (`Config.Actions`).

## Adding Custom Detectors

1.  Create a new Lua file in `NexusGuard/client/detectors/`.
2.  Follow the structure of `NexusGuard/client/detectors/detector_template.lua`.
3.  Define a unique `DetectorName`. This name will be used in `Config.Detectors` to enable/disable it.
4.  Implement the `Detector.Check()` function with your detection logic. Use `_G.NexusGuard:ReportCheat(DetectorName, details)` to report violations (this handles the warning system and triggers the server event).
5.  Implement `Detector.Initialize()` if needed (e.g., to read specific config values).
6.  The registration block at the end will automatically register and start your detector if `Config.Detectors[DetectorName]` is set to `true`.

## API / Exports

NexusGuard currently exports a minimal API:

```lua
-- Example Usage from another server script:
local NexusGuardAPI = exports['NexusGuard']:GetNexusGuardAPI()

if NexusGuardAPI then
    -- Example (if you implement these functions in the API table in globals.lua):
    -- local isFlagged = NexusGuardAPI.isPlayerFlagged(playerId)
    -- NexusGuardAPI.reportSuspiciousActivity(sourcePlayerId, targetPlayerId, "Reason")
end
```

*Note: The specific functions available in the API table are defined at the bottom of `globals.lua`. Add functions there as needed, ensuring they are secure.*

## Contribution

Contributions are welcome! Please follow these guidelines:

1.  **Fork** the repository.
2.  Create a new **branch** for your feature or bug fix (`git checkout -b feature/your-feature-name`).
3.  Write **clear and concise** code with comments.
4.  Ensure your changes **do not break** existing functionality.
5.  Test your changes thoroughly.
6.  Submit a **Pull Request** with a detailed description of your changes.

## License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.
