# ======================================
# RustMonthlyWipe
# Version: 1.0
# Owner: potaetobag
# Description: Stops all Rust-related processes, sends Discord alerts,
#              updates Oxide, backs up plugin data, wipes selected files,
#              and restarts the server. Logs actions to a daily log file.
# ======================================

# CONFIGURATION
$rustServerDir = "C:\Rust\Server"
$oxideDownloadUrl = "https://umod.org/games/rust/download/develop"
$serverStartScript = "$rustServerDir\RustServer.bat"
$backupDir = "$rustServerDir\backups"
$logDir = "$rustServerDir\logs"
$logFile = Join-Path $logDir "RustMonthlyWipe_$(Get-Date -Format 'yyyy-MM-dd').log"

$dataFilesToWipe = @(
    "$rustServerDir\oxide\data\Kits\player_data.json"
)

$discordWebhook = "URL"

# Ensure log directory exists
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# FUNCTIONS
function Log {
    param([string]$msg)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$time - $msg"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

function Send-DiscordMessage {
    param([string]$message)
    try {
        $jsonBody = @{ content = $message } | ConvertTo-Json -Depth 3
        $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
        $request = [System.Net.HttpWebRequest]::Create($discordWebhook)
        $request.Method = "POST"
        $request.ContentType = "application/json"
        $request.ContentLength = $utf8Bytes.Length
        $requestStream = $request.GetRequestStream()
        $requestStream.Write($utf8Bytes, 0, $utf8Bytes.Length)
        $requestStream.Close()
        $response = $request.GetResponse()
        $response.Close()
        Log "✅ Discord notification sent."
    } catch {
        Log "❌ Failed to send Discord notification: $_"
    }
}

function Kill-AllRustProcesses {
    Log "🔪 Terminating all Rust-related processes..."

    $currentPID = $PID
    $parentPID = (Get-CimInstance Win32_Process -Filter "ProcessId = $currentPID").ParentProcessId
    $grandparentPID = (Get-CimInstance Win32_Process -Filter "ProcessId = $parentPID").ParentProcessId

    $processNames = @(
        "RustDedicated",
        "UnityCrashHandler64",
        "mono",
        "Oxide.Compiler",
        "steamcmd",
        "steamerrorreporter"
    )

    foreach ($name in $processNames) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        foreach ($proc in $procs) {
            if ($proc.Id -ne $currentPID -and $proc.Id -ne $parentPID -and $proc.Id -ne $grandparentPID) {
                try {
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    Log "❌ Terminated: $($proc.ProcessName) (PID: $($proc.Id))"
                } catch {
                    Log "⚠️ Failed to terminate $($proc.ProcessName): $_"
                }
            }
        }
    }

    # Taskkill fallback for steamcmd and steamerrorreporter
    foreach ($fallback in @("steamcmd.exe", "steamerrorreporter.exe")) {
        Log "🪓 Forcing taskkill on $fallback..."
        cmd.exe /c "taskkill /f /im $fallback" | Out-Null
        Log "✅ taskkill issued for $fallback"
    }

    # Kill CMDs that launched RustServerInstance
    $cmds = Get-CimInstance Win32_Process -Filter "Name = 'cmd.exe'" | Where-Object {
        $_.CommandLine -match "RustServerInstance" -or $_.CommandLine -match "RustServer.bat"
    }

    foreach ($cmd in $cmds) {
        if ($cmd.ProcessId -ne $currentPID -and $cmd.ProcessId -ne $parentPID -and $cmd.ProcessId -ne $grandparentPID) {
            try {
                Stop-Process -Id $cmd.ProcessId -Force -ErrorAction Stop
                Log "❌ Terminated RustServerInstance CMD (PID: $($cmd.ProcessId))"
            } catch {
                Log "⚠️ Failed to terminate CMD (PID: $($cmd.ProcessId)): $_"
            }
        }
    }

    Start-Sleep -Seconds 3

    $leftovers = Get-Process | Where-Object {
        ($_.ProcessName -in $processNames) -and
        ($_.Id -ne $currentPID -and $_.Id -ne $parentPID -and $_.Id -ne $grandparentPID)
    }

    if ($leftovers.Count -eq 0) {
        Log "✅ All Rust-related processes terminated."
    } else {
        Log "⚠️ Some processes could not be terminated. Please review manually:"
        $leftovers | ForEach-Object {
            Log "⚠️ Still running: $($_.ProcessName) (PID: $($_.Id))"
        }
    }
}

# SCRIPT START
Log "🔍 Checking for running Rust processes..."
Kill-AllRustProcesses
Send-DiscordMessage "🛑 Rust server shutting down for monthly wipe..."

Start-Sleep -Seconds 5

# Update Oxide
try {
    $oxideZip = "$env:TEMP\oxide.zip"
    Log "⬇️ Downloading Oxide (uMod)..."
    Invoke-WebRequest -Uri $oxideDownloadUrl -OutFile $oxideZip -ErrorAction Stop
    Log "📦 Extracting Oxide..."
    Expand-Archive -Force -Path $oxideZip -DestinationPath $rustServerDir
    Remove-Item $oxideZip -Force
    Log "✅ Oxide updated."
} catch {
    Log "❌ Failed to update Oxide: $_"
}

# Backup Plugin Data
if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupPath = "$backupDir\plugin-data-backup-$timestamp.zip"

Log "💾 Backing up plugin data..."
$existingFiles = $dataFilesToWipe | Where-Object { Test-Path $_ }
if ($existingFiles.Count -gt 0) {
    Compress-Archive -Path $existingFiles -DestinationPath $backupPath -Force
    Log "✅ Backup saved: $backupPath"
} else {
    Log "⚠️ No plugin data files found to backup."
}

# Wipe Plugin Data
foreach ($file in $dataFilesToWipe) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Log "🧹 Deleted: $file"
    } else {
        Log "⚠️ Not found (skipped): $file"
    }
}

# Notify and Restart
Send-DiscordMessage "✅ Rust server updated, plugin data wiped. Restarting now..."
Log "🚀 Starting Rust server..."
Start-Process -FilePath $serverStartScript
Log "✅ Rust server start command executed."
