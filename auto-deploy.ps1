# Auto-deploy script for Isabella Birthday Website
# Polls for git changes and automatically commits/pushes to GitHub

param(
    [int]$IntervalSeconds = 3
)

$repoPath = $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Auto-Deploy Watcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Watching: $repoPath" -ForegroundColor White
Write-Host "Checking every $IntervalSeconds seconds" -ForegroundColor White
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Push-Location $repoPath

try {
    while ($true) {
        # Check for any changes (staged or unstaged)
        $status = git status --porcelain 2>$null

        if ($status) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            # Get list of changed files for commit message
            $changedFiles = ($status | ForEach-Object { $_.Substring(3) }) -join ", "

            Write-Host "[$timestamp] Changes detected!" -ForegroundColor Magenta
            Write-Host "Files: $changedFiles" -ForegroundColor Gray

            # Stage all changes
            git add -A

            # Create commit message
            $commitMsg = "Auto-update: $changedFiles"
            if ($commitMsg.Length -gt 72) {
                $fileCount = ($status | Measure-Object).Count
                $commitMsg = "Auto-update: $fileCount file(s) changed - $timestamp"
            }

            # Commit
            $commitResult = git commit -m $commitMsg 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "Committed: $commitMsg" -ForegroundColor Green

                # Push to remote
                Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
                $pushResult = git push origin master 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Pushed successfully! Site will rebuild shortly." -ForegroundColor Green
                    Write-Host "View at: https://notkeltan.github.io/isabella-birthday/" -ForegroundColor Cyan
                } else {
                    Write-Host "Push failed: $pushResult" -ForegroundColor Red
                }
            } else {
                Write-Host "Commit skipped (no changes or error)" -ForegroundColor Gray
            }

            Write-Host ""
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
}
finally {
    Pop-Location
    Write-Host ""
    Write-Host "Watcher stopped." -ForegroundColor Yellow
}
