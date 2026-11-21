# ExeForge Build GUI for Happy Birds
# Runs the original build commands (npm install && npm run build) inside a hidden
# process and shows a professional progress window. No CMD/console is displayed.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$workDir = $PSScriptRoot
if (-not $workDir) { $workDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$ui = [hashtable]::Synchronized(@{})
$sync = [hashtable]::Synchronized(@{
    Output = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    ExitCode = -1
    Done = $false
})
$ui.Sync = $sync
$ui.WorkDir = $workDir
$ui.State = @{ Phase = 0; Progress = 0 }
$ui.Phases = @(
    "Preparing build environment...",
    "Installing dependencies...",
    "Compiling application...",
    "Generating executable...",
    "Finalizing build..."
)

$form = New-Object System.Windows.Forms.Form
$form.Text = "Building Your EXE"
$form.Size = New-Object System.Drawing.Size(580, 430)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = [System.Drawing.Color]::White
$form.ForeColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$ui.Form = $form

$title = New-Object System.Windows.Forms.Label
$title.Text = "Building Your EXE"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(30, 20)
$title.Size = New-Object System.Drawing.Size(520, 34)
$title.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Please wait while your application is being compiled."
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.Location = New-Object System.Drawing.Point(30, 56)
$subtitle.Size = New-Object System.Drawing.Size(520, 20)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$ui.Subtitle = $subtitle
$form.Controls.Add($subtitle)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Preparing build environment..."
$status.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$status.Location = New-Object System.Drawing.Point(30, 95)
$status.Size = New-Object System.Drawing.Size(520, 24)
$ui.Status = $status
$form.Controls.Add($status)

$bar = New-Object System.Windows.Forms.ProgressBar
$bar.Location = New-Object System.Drawing.Point(30, 125)
$bar.Size = New-Object System.Drawing.Size(500, 26)
$bar.Style = "Continuous"
$bar.Minimum = 0
$bar.Maximum = 100
$bar.Value = 0
$ui.Bar = $bar
$form.Controls.Add($bar)

$pct = New-Object System.Windows.Forms.Label
$pct.Text = "0%"
$pct.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$pct.Location = New-Object System.Drawing.Point(30, 155)
$pct.Size = New-Object System.Drawing.Size(500, 20)
$pct.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$ui.Pct = $pct
$form.Controls.Add($pct)

$result = New-Object System.Windows.Forms.Label
$result.Text = ""
$result.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$result.Location = New-Object System.Drawing.Point(30, 185)
$result.Size = New-Object System.Drawing.Size(520, 30)
$result.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$result.Visible = $false
$ui.Result = $result
$form.Controls.Add($result)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.WordWrap = $false
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logBox.Location = New-Object System.Drawing.Point(30, 185)
$logBox.Size = New-Object System.Drawing.Size(500, 130)
$logBox.Visible = $false
$ui.LogBox = $logBox
$form.Controls.Add($logBox)

$openBtn = New-Object System.Windows.Forms.Button
$openBtn.Text = "OPEN DIST FOLDER"
$openBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$openBtn.Location = New-Object System.Drawing.Point(30, 330)
$openBtn.Size = New-Object System.Drawing.Size(240, 42)
$openBtn.FlatStyle = "Flat"
$openBtn.BackColor = [System.Drawing.Color]::FromArgb(34, 197, 94)
$openBtn.ForeColor = [System.Drawing.Color]::White
$openBtn.Visible = $false
$openBtn.Add_Click({
    $dist = Join-Path $ui.WorkDir "dist"
    if (Test-Path $dist) { Start-Process explorer.exe -ArgumentList $dist }
})
$ui.OpenBtn = $openBtn
$form.Controls.Add($openBtn)

$finishBtn = New-Object System.Windows.Forms.Button
$finishBtn.Text = "FINISH"
$finishBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$finishBtn.Location = New-Object System.Drawing.Point(290, 330)
$finishBtn.Size = New-Object System.Drawing.Size(240, 42)
$finishBtn.FlatStyle = "Flat"
$finishBtn.BackColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
$finishBtn.ForeColor = [System.Drawing.Color]::White
$finishBtn.Visible = $false
$finishBtn.Add_Click({ $ui.Form.Close() })
$ui.FinishBtn = $finishBtn
$form.Controls.Add($finishBtn)

$viewLogBtn = New-Object System.Windows.Forms.Button
$viewLogBtn.Text = "VIEW BUILD LOG"
$viewLogBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$viewLogBtn.Location = New-Object System.Drawing.Point(30, 330)
$viewLogBtn.Size = New-Object System.Drawing.Size(500, 42)
$viewLogBtn.FlatStyle = "Flat"
$viewLogBtn.BackColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
$viewLogBtn.ForeColor = [System.Drawing.Color]::White
$viewLogBtn.Visible = $false
$viewLogBtn.Add_Click({
    $ui.LogBox.Text = ($ui.Sync.Output -join [System.Environment]::NewLine)
    $ui.LogBox.Visible = $true
})
$ui.ViewLogBtn = $viewLogBtn
$form.Controls.Add($viewLogBtn)

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "cmd.exe"
$psi.Arguments = "/c call npm install && call npm run build"
$psi.WorkingDirectory = $workDir
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true
$psi.WindowStyle = "Hidden"

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
$proc.EnableRaisingEvents = $true
$ui.Proc = $proc

Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -MessageData $sync -Action {
    if ($EventArgs.Data -ne $null -and $EventArgs.Data -ne "") {
        [void]$MessageData.Output.Add($EventArgs.Data)
    }
} | Out-Null

Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -MessageData $sync -Action {
    if ($EventArgs.Data -ne $null -and $EventArgs.Data -ne "") {
        [void]$MessageData.Output.Add($EventArgs.Data)
    }
} | Out-Null

Register-ObjectEvent -InputObject $proc -EventName Exited -MessageData $sync -Action {
    $MessageData.ExitCode = $Sender.ExitCode
    $MessageData.Done = $true
} | Out-Null

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    $sync.Output.Add("Node.js was not found on this system.")
    $sync.Output.Add("Please install Node.js 18 or newer from https://nodejs.org and try again.")
    $sync.ExitCode = 1
    $sync.Done = $true
} else {
    try {
        $proc.Start() | Out-Null
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()
    } catch {
        $sync.Output.Add("Failed to start the build process: " + $_.Exception.Message)
        $sync.ExitCode = 1
        $sync.Done = $true
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250

# Phase ceilings: the progress bar may not exceed these until the next phase.
# The final phase (4) caps at 97 — 100 is reserved for verified success only,
# so the bar never falsely reports completion while the EXE is still building.
$caps = @(8, 40, 65, 85, 97)

$timer.Add_Tick({
    $s = $ui.Sync
    $st = $ui.State
    $lines = $s.Output
    $joined = ""
    if ($lines.Count -gt 0) { $joined = ($lines -join " ").ToLower() }

    # ── Phase detection from real build output ──
    if ($joined -match "added " -or $joined -match "up to date" -or $joined -match "npm warn" -or $joined -match "changed " -or $joined -match "npm install") {
        if ($st.Phase -lt 1) { $st.Phase = 1 }
    }
    if ($joined -match "electron-builder" -or $joined -match "packaging" -or $joined -match "> electron-builder" -or $joined -match "building") {
        if ($st.Phase -lt 2) { $st.Phase = 2 }
    }
    if ($joined -match "building target" -or $joined -match "block map" -or $joined -match "unpacking" -or $joined -match "compressing" -or $joined -match "signing" -or $joined -match "building app") {
        if ($st.Phase -lt 3) { $st.Phase = 3 }
    }
    if ($s.Done -and $st.Phase -lt 4) { $st.Phase = 4 }

    $ui.Status.Text = $ui.Phases[$st.Phase]

    # ── Smooth, time-aware progression toward the current phase ceiling ──
    $cap = $caps[$st.Phase]
    if ($st.Progress -lt $cap) {
        # Larger steps early, smaller as we approach the cap — keeps it moving
        # smoothly without ever overshooting into "done" territory.
        $remaining = $cap - $st.Progress
        $step = [Math]::Max(1, [Math]::Round($remaining / 8))
        $st.Progress = [Math]::Min($cap, $st.Progress + $step)
    }
    $ui.Bar.Value = $st.Progress
    $ui.Pct.Text = "$($st.Progress)%"

    # ── Continuous dist-folder monitoring for the generated EXE ──
    $dist = Join-Path $ui.WorkDir "dist"
    $exe = $null
    if (Test-Path $dist) {
        $exe = Get-ChildItem -Path $dist -Filter *.exe -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "Uninstall" } | Select-Object -First 1
    }

    # Track EXE size stability so we never report success on a half-written file.
    if ($exe) {
        $sizeKey = $exe.FullName
        $sizeNow = $exe.Length
        if (-not $st.ExePath) { $st.ExePath = $sizeKey; $st.ExeSize = $sizeNow; $st.ExeStableSince = 0 }
        elseif ($st.ExePath -eq $sizeKey) {
            if ($sizeNow -eq $st.ExeSize) {
                if ($st.ExeStableSince -eq 0) { $st.ExeStableSince = [System.Environment]::TickCount }
            } else {
                $st.ExeSize = $sizeNow
                $st.ExeStableSince = 0
            }
        } else {
            $st.ExePath = $sizeKey; $st.ExeSize = $sizeNow; $st.ExeStableSince = 0
        }
    }

    # An EXE is considered "fully written" once its size has been stable for
    # at least 1.2 seconds (the writer has closed the file).
    $exeReady = $false
    if ($exe -and $st.ExeStableSince -gt 0) {
        $exeReady = ([System.Environment]::TickCount - $st.ExeStableSince) -ge 1200
    }

    # ── Success: process finished AND EXE verified present + stable ──
    if ($s.Done -and $s.ExitCode -eq 0 -and $exeReady) {
        $timer.Stop()
        $ui.Bar.Value = 100
        $st.Progress = 100
        $ui.Pct.Text = "100%"
        $ui.Status.Text = "BUILD COMPLETED SUCCESSFULLY!"
        $ui.Status.ForeColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
        $ui.Result.Text = "Your executable is ready. Open the dist folder to find your generated EXE."
        $ui.Result.ForeColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
        $ui.Result.Visible = $true
        $ui.OpenBtn.Visible = $true
        $ui.FinishBtn.Visible = $true

        # Automatically close the window after a short delay (~2 seconds).
        # The user does not need to click FINISH.
        $closeTimer = New-Object System.Windows.Forms.Timer
        $closeTimer.Interval = 2000
        $closeTimer.Add_Tick({ $closeTimer.Stop(); $closeTimer.Dispose(); $ui.Form.Close() })
        $closeTimer.Start()
        return
    }

    # ── Failure: process exited without a verified EXE ──
    if ($s.Done -and -not ($s.ExitCode -eq 0 -and $exeReady)) {
        $timer.Stop()
        $ui.Status.Text = "BUILD FAILED"
        $ui.Status.ForeColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
        $ui.Result.Text = "The executable was not generated. Review the build log for details."
        $ui.Result.ForeColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
        $ui.Result.Visible = $true
        $ui.ViewLogBtn.Visible = $true
    }
})

$timer.Start()
$form.ShowDialog() | Out-Null
$timer.Dispose()
if ($proc -and -not $proc.HasExited) { try { $proc.Kill() } catch {} }
$proc.Close()
