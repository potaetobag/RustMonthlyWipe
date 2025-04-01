`RustMonthlyWipe.ps1` is a PowerShell script designed to simplify and automate monthly maintenance tasks for a Rust game server. This script:

- 🛑 Stops all Rust-related processes
- 📢 Sends status alerts to a configured Discord webhook
- 🔄 Updates the Oxide (uMod) plugin
- 💾 Backs up selected plugin data
- 🧹 Wipes specific plugin data files
- 🚀 Restarts the server
- 📝 Logs all actions to a timestamped file

---

## File Structure
```
C:\Rust\Server\
├── backups\                 # Stores zipped plugin backups
├── logs\                    # Stores daily logs from RustMonthlyWipe
├── oxide\                   # Oxide directory containing plugin data
├── RustServer.bat            # Your Rust server startup script
└── RustMonthlyWipe.ps1       # This script
```

---

## Configuration
### Required Paths (already set in the script):
- `$rustServerDir`: Base Rust server directory
- `$oxideDownloadUrl`: URL to download the latest Oxide build
- `$serverStartScript`: Script to start your Rust server
- `$backupDir`: Where plugin data backups are saved
- `$logDir`: Where logs are written

### Customizable:
- `$dataFilesToWipe`: Array of plugin data files you want wiped monthly
- `$discordWebhook`: URL for your Discord notifications

---

## Logging
All actions are logged to a file named like:
```
RustMonthlyWipe_YYYY-MM-DD.log
```
Found under the `logs\` folder.

---

## How to Use
1. Ensure your Rust server is installed at `C:\Rust\Server\`
2. Configure `RustServer.bat` properly to start your Rust server
3. Run the PowerShell script as administrator:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\RustMonthlyWipe.ps1
```

---

## Notes
- The script uses a combination of `Stop-Process`, `taskkill`, and `WMI` queries to shut down all processes related to the Rust server.
- It avoids killing itself by checking parent/child/grandparent process IDs.
- Logs help with debugging and visibility.
- Designed to work with recurring wipe events.

---

## License
MIT License. Use freely, modify with love, and don't forget to back up your configs.
