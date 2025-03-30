# NexusGuard - Modular FiveM Anti-Cheat Framework (v0.6.9)

NexusGuard is a modular, event-driven anti-cheat framework designed for FiveM servers. It provides a core structure and several basic detection modules, intended to be customized and extended by server developers.

**⚠️ This is an open-source framework, not a plug-and-play solution. ⚠️** It requires careful configuration and **significant implementation** of server-specific logic (permissions, bans, database integration, **critical security measures**) to function effectively and securely. **Do not deploy this on a live server without addressing the security placeholders.**

## Features (Core Framework)

*   **Modular Detector System**: Easily enable, disable, or create custom detection modules (`client/detectors/`).
*   **Event-Driven Architecture**: Uses standardized events for communication via `shared/EventRegistry.lua` (Required).
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
*   **[ox_lib](https://github.com/overextended/ox_lib)**: Required for the default secure token implementation (HMAC-SHA256). Provides `lib.crypto`. **Must be started before NexusGuard.**

**Optional:**

*   **`chat` resource**: Recommended for displaying client-side warnings via the `NexusGuard:CheatWarning` event. If not used, warnings will only appear in the F8 console.
*   **Framework for Permissions (ESX/QBCore)**: If you set `Config.PermissionsFramework` to `"esx"` or `"qbcore"`, the corresponding framework (`es_extended` or `qb-core`) must be running and started *before* NexusGuard for admin checks to function correctly.
*   **External Discord Bot**: If using advanced Discord bot features (commands, player reports beyond webhooks) defined in `config.lua`, a separate bot implementation (e.g., using discord.js, discord.py, etc.) interacting with NexusGuard (potentially via custom events or API calls) is required. This framework only provides basic webhook logging and Rich Presence.

## Installation

1.  **Download:** Download the latest release (v0.6.9) of NexusGuard.
2.  **Extract:** Extract the `NexusGuard` folder into your server's `resources` directory.
3.  **Dependencies:** Ensure **oxmysql** and **screenshot-basic** are installed and listed in your `server.cfg` to start *before* NexusGuard. Install optional dependencies (like `chat`) as needed. **Note:** The `shared/event_registry.lua` included in this resource is essential for its operation.
4.  **Database Setup:**
    *   Ensure you have a MySQL database server accessible by your FiveM server.
    *   Import the `NexusGuard/sql/schema.sql` file into your database. This will create the necessary tables (`nexusguard_bans`, `nexusguard_detections`, `nexusguard_sessions`).
    *   Ensure your `oxmysql` resource is correctly configured to connect to your database.
5.  **Configure `config.lua`:**
    *   Carefully review **all** options in `config.lua`.
    *   Carefully review **all** options in `config.lua`. Pay close attention to comments indicating required fields or critical settings.
    *   **CRITICAL:** Set `Config.SecuritySecret` to a **long, unique, and random string**. This secret is used by the default secure token implementation (HMAC-SHA256). **Do not leave the default value or share it.**
    *   **Set `Config.PermissionsFramework`:** Choose `"ace"`, `"esx"`, `"qbcore"`, or `"custom"` based on your server's permission system. See comments in `config.lua`.
    *   **Configure `Config.AdminGroups`:** List the group/permission names that should be considered admin *according to the framework selected above*. (e.g., for ACE: `"admin"`, `"superadmin"`; for ESX: `"admin"`, `"superadmin"`; for QBCore: `"admin"`, `"god"`, etc.).
    *   Fill in required URLs/IDs if features are enabled: `Config.DiscordWebhook` (for general logs), specific webhook URLs in `Config.Discord.webhooks` (optional), `Config.ScreenCapture.webhookURL`, `Config.Discord.RichPresence.AppId`.
    *   If enabling `Config.Features.resourceVerification`, carefully configure the `whitelist` or `blacklist`. **Whitelist mode requires adding ALL essential server resources (framework, maps, scripts) to prevent false kicks/bans.** See comments in `config.lua`.
    *   Adjust detection thresholds (`Config.Thresholds`) and enable/disable detectors (`Config.Detectors`) based on testing and server needs.
6.  **Implement Custom Logic (If Needed):**
    *   **Custom Permissions:** If you set `Config.PermissionsFramework = "custom"`, you **MUST** edit the `IsPlayerAdmin` function in `globals.lua` to add your specific permission checking logic.
    *   **(Optional) AI & Other Placeholders:** Review other functions marked as placeholders (AI functions, `HandleEntityCreation`) and implement them if you intend to use those features.
7.  **Server Config:** Add `ensure NexusGuard` to your `server.cfg`, ensuring it starts *after* its dependencies (`oxmysql`, `screenshot-basic`, `ox_lib`, and potentially `es_extended` or `qb-core` if selected).
8.  **Restart Server & Test:** Restart your FiveM server. Check the console thoroughly for any NexusGuard errors or warnings (especially critical ones about missing dependencies or security). Test detections and actions rigorously, paying close attention to admin checks.
    *   **(Optional) AI & Other Placeholders:** Review other functions marked as placeholders (AI functions, `HandleEntityCreation`) and implement them if you intend to use those features.
7.  **Server Config:** Add `ensure NexusGuard` to your `server.cfg`, ensuring it starts *after* its dependencies (`oxmysql`, `screenshot-basic`, `ox_lib`).
8.  **Restart Server & Test:** Restart your FiveM server. Check the console thoroughly for any NexusGuard errors or warnings (especially critical ones about missing functions or security). Test detections and actions rigorously.

## Configuration Deep Dive

*   **`config.lua`**: Contains all user-configurable settings. Read the comments carefully.
*   **`Config.SecuritySecret`**: **MUST BE CHANGED** to a strong, unique secret. This is used by the default secure token system.
*   **Security Implementation**: A default secure token system using HMAC-SHA256 (via `ox_lib`) is now included. Ensure `ox_lib` is installed and `Config.SecuritySecret` is set correctly.
*   **Permissions**: Configure `Config.PermissionsFramework` and `Config.AdminGroups` in `config.lua`. You only need to edit `globals.lua` if using the `"custom"` framework setting.
*   **Resource Verification**: The logic is implemented, but if enabled, the `whitelist` or `blacklist` in `config.lua` **MUST BE CONFIGURED ACCURATELY**. Whitelist mode is dangerous if not all required resources are listed.
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

## Common Issues & Troubleshooting

*   **CRITICAL: `Config.SecuritySecret` Error / Invalid Token Errors:**
    *   **Cause:** You haven't changed `Config.SecuritySecret` in `config.lua` from the default value, or `ox_lib` is not started *before* NexusGuard.
    *   **Solution:**
        1.  **STOP YOUR SERVER.**
        2.  Open `config.lua` and set `Config.SecuritySecret` to a **long, unique, random string** (e.g., use a password generator). **DO NOT SHARE THIS SECRET.**
        3.  Ensure `ensure ox_lib` is listed **before** `ensure NexusGuard` in your `server.cfg`.
        4.  Restart your server.

*   **Players Kicked/Banned Incorrectly by Resource Verification:**
    *   **Cause:** If using `Config.Features.resourceVerification.mode = "whitelist"`, you haven't added all essential server resources to the `whitelist` table in `config.lua`.
    *   **Solution:**
        1.  Temporarily set `Config.Features.resourceVerification.enabled = false` in `config.lua` to stop the kicks/bans.
        2.  Restart NexusGuard (`restart NexusGuard`).
        3.  As an admin in-game, run the command `/nexusguard_getresources`.
        4.  Copy the entire list printed in your chat (including the `{` and `}` braces).
        5.  Paste this list into the `Config.Features.resourceVerification.whitelist` table in `config.lua`, replacing the default example list.
        6.  Review the pasted list and remove any non-essential or temporary resources if desired.
        7.  Set `Config.Features.resourceVerification.enabled = true` again.
        8.  Restart NexusGuard (`restart NexusGuard`).

*   **Admin Commands Don't Work / Not Detected as Admin:**
    *   **Cause:** `Config.PermissionsFramework` is not set correctly, `Config.AdminGroups` doesn't match your framework's groups, or the required framework (ESX/QBCore) isn't started before NexusGuard.
    *   **Solution:**
        1.  Verify `Config.PermissionsFramework` in `config.lua` matches your server ("ace", "esx", "qbcore").
        2.  Verify `Config.AdminGroups` contains the exact group names used by your framework for admins (case-sensitive). Check your framework's documentation or database if unsure.
        3.  If using "esx" or "qbcore", ensure `ensure es_extended` or `ensure qb-core` is listed **before** `ensure NexusGuard` in your `server.cfg`.

*   **Database Errors (Connection, Schema):**
    *   **Cause:** `oxmysql` is not configured correctly, not started before NexusGuard, or the database schema wasn't imported.
    *   **Solution:**
        1.  Ensure `oxmysql` is installed and configured with your correct database credentials.
        2.  Ensure `ensure oxmysql` is listed **before** `ensure NexusGuard` in your `server.cfg`.
        3.  Verify you imported `NexusGuard/sql/schema.sql` into your database. Check the server console for specific MySQL errors during startup.

*   **Screenshot Errors:**
    *   **Cause:** `screenshot-basic` resource is missing or not started before NexusGuard, or `Config.ScreenCapture.webhookURL` is incorrect or missing.
    *   **Solution:**
        1.  Ensure `screenshot-basic` is installed.
        2.  Ensure `ensure screenshot-basic` is listed **before** `ensure NexusGuard` in your `server.cfg`.
        3.  Verify `Config.ScreenCapture.webhookURL` in `config.lua` is a valid Discord webhook URL.

*   **False Positives (Speed, Teleport, etc.):**
    *   **Cause:** Default thresholds in `Config.Thresholds` might be too strict for your server or specific situations (e.g., custom vehicles, specific framework teleports).
    *   **Solution:** Gradually increase the relevant threshold values in `Config.Thresholds` (e.g., `speedHackMultiplier`, `teleportDistance`) and test thoroughly. Monitor server console logs for detection messages to identify patterns.

*   **"[NexusGuard] CRITICAL: _G.EventRegistry not found..." Error:**
    *   **Cause:** The essential `shared/event_registry.lua` script is not being loaded correctly.
    *   **Solution:** Ensure `shared/event_registry.lua` exists and is correctly listed under `shared_scripts` in your `fxmanifest.lua`.

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
