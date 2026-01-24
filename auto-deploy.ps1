# Auto-deploy script for Isabella Birthday Website
# Watches for file changes and automatically commits/pushes to GitHub

$watchPath = $PSScriptRoot
$filter = "*.*"

Write-Host "Starting auto-deploy watcher..." -ForegroundColor Green
Write-Host "Watching: $watchPath" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $watchPath
$watcher.Filter = $filter
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Debounce mechanism to avoid multiple triggers
$script:lastChange = [DateTime]::MinValue
$script:debounceSeconds = 2

$action = {
    $path = $Event.SourceEventArgs.FullPath
    $changeType = $Event.SourceEventArgs.ChangeType
    $name = $Event.SourceEventArgs.Name

    # Skip .git folder and this script
    if ($path -match '\.git\\' -or $name -eq 'auto-deploy.ps1') {
        return
    }

    # Skip non-web files
    if (-not ($name -match '\.(html|css|js|png|jpg|jpeg|gif|svg|ico|md)$')) {
        return
    }

    # Debounce
    $now = [DateTime]::Now
    if (($now - $script:lastChange).TotalSeconds -lt $script:debounceSeconds) {
        return
    }
    $script:lastChange = $now

    # Wait a moment for file to be fully written
    Start-Sleep -Milliseconds 500

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] Change detected: $name ($changeType)" -ForegroundColor Magenta

    # Change to the watch directory
    Push-Location $watchPath

    try {
        # Stage all changes
        git add -A

        # Check if there are changes to commit
        $status = git status --porcelain
        if ($status) {
            # Commit with timestamp
            $commitMsg = "Auto-update: $name - $timestamp"
            git commit -m $commitMsg

            Write-Host "Committed: $commitMsg" -ForegroundColor Green

            # Push to remote
            git push origin master

            Write-Host "Pushed to GitHub - site will rebuild shortly" -ForegroundColor Green
            Write-Host ""
        }
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
}

# Register event handlers
Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null
Register-ObjectEvent $watcher "Deleted" -Action $action | Out-Null
Register-ObjectEvent $watcher "Renamed" -Action $action | Out-Null

Write-Host "Watcher is running. Edit your files and they'll auto-deploy!" -ForegroundColor Green
Write-Host ""

# Keep script running
try {
    while ($true) { Start-Sleep -Seconds 1 }
}
finally {
    # Cleanup
    $watcher.EnableRaisingEvents = $false
    Get-EventSubscriber | Unregister-Event
    $watcher.Dispose()
    Write-Host "Watcher stopped." -ForegroundColor Yellow
}
