<#
.SYNOPSIS
    GUI tool to browse Azure AD B2C email / phone verification audit logs via Microsoft Graph beta.

.DESCRIPTION
    Sign in interactively, choose Email or Phone verification activities, pick a preset window
    (Last 24 hours / 3 days / 7 days) or a custom date range, then query
    https://graph.microsoft.com/beta/auditLogs/directoryAudits.

    Results are shown in a grid (UTC timestamp, Activity, Status / Status Reason, Email or Phone,
    Correlation ID), can be filtered by a string match on any/all columns, and exported to CSV.

    Graph requests page through @odata.nextLink and retry on 429 / 500 / 503 / 504 with
    Retry-After honoring plus exponential backoff and jitter.

.NOTES
    Requires the Microsoft.Graph.Authentication PowerShell module.
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
    Delegated scopes requested: AuditLog.Read.All, Directory.Read.All
#>

#Requires -Modules Microsoft.Graph.Authentication

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------------ state ----
$script:AllRows      = @()      # full result set (ordered PSCustomObjects)
$script:ContactLabel = 'Email'  # dynamic contact column header

$script:ActivityMap = @{
    Email = @('Verify email address', 'Send verification email')
    Phone = @('Verify phone number', 'Send SMS to verify phone number', 'Make phone call to verify phone number')
}

# ------------------------------------------------------------- graph helpers -

function Invoke-GraphWithRetry {
    <#  GET a Graph URI with throttling / transient-error handling. #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [int]$MaxRetries = 6
    )

    $attempt = 0
    while ($true) {
        try {
            $json = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType Json -ErrorAction Stop
            return ($json | ConvertFrom-Json)
        }
        catch {
            $attempt++

            # Determine HTTP status code from the failure.
            $status = $null
            try { $status = [int]$_.Exception.Response.StatusCode } catch { }
            if (-not $status -and $_.Exception.Message -match '\b(429|500|503|504)\b') {
                $status = [int]$Matches[1]
            }

            $retryable = @(429, 500, 503, 504)
            if (($status -in $retryable) -and ($attempt -le $MaxRetries)) {

                # Prefer the server-supplied Retry-After when present.
                $retryAfter = 0
                try   { $retryAfter = [int]$_.Exception.Response.Headers['Retry-After'] } catch { }
                if ($retryAfter -le 0) {
                    try { $retryAfter = [int]([double]$_.Exception.Response.Headers.RetryAfter.Delta.TotalSeconds) } catch { }
                }
                if ($retryAfter -le 0) {
                    $retryAfter = [math]::Min(60, [math]::Pow(2, $attempt))   # exponential backoff cap 60s
                }

                $wait = [int]$retryAfter + (Get-Random -Minimum 0 -Maximum 3) # jitter
                Set-Status ("Throttled/transient (HTTP {0}). Backing off {1}s (attempt {2}/{3})..." -f $status, $wait, $attempt, $MaxRetries)
                Start-Sleep -Seconds $wait
                continue
            }
            throw
        }
    }
}

function Get-ContactValue {
    <#  Best-effort extraction of the email address or phone number from a record. #>
    param(
        [Parameter(Mandatory)]$Record,
        [Parameter(Mandatory)][ValidateSet('Email', 'Phone')][string]$Mode
    )

    $candidates = New-Object System.Collections.Generic.List[string]

    $add = {
        param($v)
        if ($null -ne $v) {
            $s = ([string]$v).Trim().Trim('"')
            if ($s) { $candidates.Add($s) }
        }
    }

    foreach ($tr in @($Record.targetResources)) {
        & $add $tr.userPrincipalName
        & $add $tr.displayName
        foreach ($mp in @($tr.modifiedProperties)) {
            & $add $mp.newValue
            & $add $mp.oldValue
        }
    }
    foreach ($ad in @($Record.additionalDetails)) { & $add $ad.value }
    & $add $Record.initiatedBy.user.userPrincipalName
    & $add $Record.initiatedBy.user.displayName

    if ($Mode -eq 'Email') {
        $m = $candidates | Where-Object { $_ -match '^[^@\s]+@[^@\s]+\.[^@\s]+$' } | Select-Object -First 1
        if (-not $m) { $m = $candidates | Where-Object { $_ -match '@' } | Select-Object -First 1 }
        return $m
    }
    else {
        $m = $candidates | Where-Object { $_ -match '^\+?[0-9][0-9\-\s\(\)]{4,}$' } | Select-Object -First 1
        return $m
    }
}

# ------------------------------------------------------------------ GUI ------

$form                = New-Object System.Windows.Forms.Form
$form.Text           = 'Azure AD B2C Verification Log Browser'
$form.Size           = New-Object System.Drawing.Size(1362, 768)
$form.StartPosition  = 'CenterScreen'
$form.MinimumSize    = New-Object System.Drawing.Size(900, 600)

# --- Sign-in row
$lblTenant = New-Object System.Windows.Forms.Label
$lblTenant.Text = 'Tenant (optional):'
$lblTenant.Location = New-Object System.Drawing.Point(12, 15)
$lblTenant.AutoSize = $true
$form.Controls.Add($lblTenant)

$txtTenant = New-Object System.Windows.Forms.TextBox
$txtTenant.Location = New-Object System.Drawing.Point(120, 12)
$txtTenant.Size = New-Object System.Drawing.Size(260, 23)
$txtTenant.PlaceholderText = 'contoso.onmicrosoft.com or tenant GUID'
$form.Controls.Add($txtTenant)

$btnSignIn = New-Object System.Windows.Forms.Button
$btnSignIn.Text = 'Sign in'
$btnSignIn.Location = New-Object System.Drawing.Point(392, 11)
$btnSignIn.Size = New-Object System.Drawing.Size(90, 25)
$form.Controls.Add($btnSignIn)

$btnSignOut = New-Object System.Windows.Forms.Button
$btnSignOut.Text = 'Sign out'
$btnSignOut.Location = New-Object System.Drawing.Point(488, 11)
$btnSignOut.Size = New-Object System.Drawing.Size(90, 25)
$btnSignOut.Enabled = $false
$form.Controls.Add($btnSignOut)

$lblAccount = New-Object System.Windows.Forms.Label
$lblAccount.Text = 'Not signed in.'
$lblAccount.Location = New-Object System.Drawing.Point(590, 15)
$lblAccount.AutoSize = $true
$lblAccount.ForeColor = [System.Drawing.Color]::Firebrick
$form.Controls.Add($lblAccount)

# --- Options group
$grpOptions = New-Object System.Windows.Forms.GroupBox
$grpOptions.Text = 'Query options'
$grpOptions.Location = New-Object System.Drawing.Point(12, 48)
$grpOptions.Size = New-Object System.Drawing.Size(1322, 120)
$grpOptions.Anchor = 'Top,Left,Right'
$form.Controls.Add($grpOptions)

# Log type (own panel so it is a separate radio group from the range selection)
$pnlLogType = New-Object System.Windows.Forms.Panel
$pnlLogType.Location = New-Object System.Drawing.Point(10, 20)
$pnlLogType.Size = New-Object System.Drawing.Size(150, 85)
$grpOptions.Controls.Add($pnlLogType)

$rbEmail = New-Object System.Windows.Forms.RadioButton
$rbEmail.Text = 'Email logs'
$rbEmail.Location = New-Object System.Drawing.Point(5, 5)
$rbEmail.AutoSize = $true
$rbEmail.Checked = $true
$pnlLogType.Controls.Add($rbEmail)

$rbPhone = New-Object System.Windows.Forms.RadioButton
$rbPhone.Text = 'Phone logs'
$rbPhone.Location = New-Object System.Drawing.Point(5, 35)
$rbPhone.AutoSize = $true
$pnlLogType.Controls.Add($rbPhone)

$chkFailures = New-Object System.Windows.Forms.CheckBox
$chkFailures.Text = 'Failures only'
$chkFailures.Location = New-Object System.Drawing.Point(5, 65)
$chkFailures.AutoSize = $true
$pnlLogType.Controls.Add($chkFailures)

# Range type
$rbPreset = New-Object System.Windows.Forms.RadioButton
$rbPreset.Text = 'Preset window:'
$rbPreset.Location = New-Object System.Drawing.Point(180, 25)
$rbPreset.AutoSize = $true
$rbPreset.Checked = $true
$grpOptions.Controls.Add($rbPreset)

$cboPreset = New-Object System.Windows.Forms.ComboBox
$cboPreset.DropDownStyle = 'DropDownList'
$cboPreset.Location = New-Object System.Drawing.Point(300, 23)
$cboPreset.Size = New-Object System.Drawing.Size(160, 23)
[void]$cboPreset.Items.AddRange(@('Last 24 hours', 'Last 3 days', 'Last 7 days'))
$cboPreset.SelectedIndex = 0
$grpOptions.Controls.Add($cboPreset)

$rbCustom = New-Object System.Windows.Forms.RadioButton
$rbCustom.Text = 'Custom range (UTC):'
$rbCustom.Location = New-Object System.Drawing.Point(180, 60)
$rbCustom.AutoSize = $true
$grpOptions.Controls.Add($rbCustom)

$lblFrom = New-Object System.Windows.Forms.Label
$lblFrom.Text = 'From:'
$lblFrom.Location = New-Object System.Drawing.Point(320, 62)
$lblFrom.AutoSize = $true
$grpOptions.Controls.Add($lblFrom)

$dtpFrom = New-Object System.Windows.Forms.DateTimePicker
$dtpFrom.Format = 'Custom'
$dtpFrom.CustomFormat = 'yyyy-MM-dd HH:mm'
$dtpFrom.ShowUpDown = $true
$dtpFrom.Location = New-Object System.Drawing.Point(360, 58)
$dtpFrom.Size = New-Object System.Drawing.Size(140, 23)
$dtpFrom.Value = [DateTime]::UtcNow.AddDays(-1)
$dtpFrom.Enabled = $false
$grpOptions.Controls.Add($dtpFrom)

$lblTo = New-Object System.Windows.Forms.Label
$lblTo.Text = 'To:'
$lblTo.Location = New-Object System.Drawing.Point(510, 62)
$lblTo.AutoSize = $true
$grpOptions.Controls.Add($lblTo)

$dtpTo = New-Object System.Windows.Forms.DateTimePicker
$dtpTo.Format = 'Custom'
$dtpTo.CustomFormat = 'yyyy-MM-dd HH:mm'
$dtpTo.ShowUpDown = $true
$dtpTo.Location = New-Object System.Drawing.Point(540, 58)
$dtpTo.Size = New-Object System.Drawing.Size(140, 23)
$dtpTo.Value = [DateTime]::UtcNow
$dtpTo.Enabled = $false
$grpOptions.Controls.Add($dtpTo)

$btnQuery = New-Object System.Windows.Forms.Button
$btnQuery.Text = 'Query logs'
$btnQuery.Location = New-Object System.Drawing.Point(1170, 30)
$btnQuery.Size = New-Object System.Drawing.Size(140, 55)
$btnQuery.Anchor = 'Top,Right'
$btnQuery.Enabled = $false
$grpOptions.Controls.Add($btnQuery)

# --- Filter row
$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Text = 'Filter column:'
$lblFilter.Location = New-Object System.Drawing.Point(12, 180)
$lblFilter.AutoSize = $true
$form.Controls.Add($lblFilter)

$cboFilterCol = New-Object System.Windows.Forms.ComboBox
$cboFilterCol.DropDownStyle = 'DropDownList'
$cboFilterCol.Location = New-Object System.Drawing.Point(100, 177)
$cboFilterCol.Size = New-Object System.Drawing.Size(180, 23)
$form.Controls.Add($cboFilterCol)

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(290, 177)
$txtFilter.Size = New-Object System.Drawing.Size(300, 23)
$txtFilter.PlaceholderText = 'contains text (case-insensitive)...'
$form.Controls.Add($txtFilter)

$btnClearFilter = New-Object System.Windows.Forms.Button
$btnClearFilter.Text = 'Clear filter'
$btnClearFilter.Location = New-Object System.Drawing.Point(600, 176)
$btnClearFilter.Size = New-Object System.Drawing.Size(90, 25)
$form.Controls.Add($btnClearFilter)

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = 'Export CSV'
$btnExport.Location = New-Object System.Drawing.Point(1224, 176)
$btnExport.Size = New-Object System.Drawing.Size(110, 25)
$btnExport.Anchor = 'Top,Right'
$btnExport.Enabled = $false
$form.Controls.Add($btnExport)

# --- Grid
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(12, 210)
$grid.Size = New-Object System.Drawing.Size(1322, 498)
$grid.Anchor = 'Top,Bottom,Left,Right'
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.AutoSizeColumnsMode = 'Fill'
$grid.RowHeadersVisible = $false
$grid.AllowUserToResizeColumns = $true
$form.Controls.Add($grid)

# --- Status bar
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = 'Ready. Sign in to begin.'
[void]$statusStrip.Items.Add($statusLabel)
$form.Controls.Add($statusStrip)

function Set-Status {
    param([string]$Text)
    $statusLabel.Text = $Text
    [System.Windows.Forms.Application]::DoEvents()
}

# ---------------------------------------------------------------- grid data --

function New-ResultTable {
    param([string]$ContactHeader)
    $dt = New-Object System.Data.DataTable
    [void]$dt.Columns.Add('Timestamp (UTC)')
    [void]$dt.Columns.Add('Activity')
    [void]$dt.Columns.Add('Status')
    [void]$dt.Columns.Add('Status Reason')
    [void]$dt.Columns.Add($ContactHeader)
    [void]$dt.Columns.Add('Correlation ID')
    return , $dt   # comma prevents PowerShell from unrolling the enumerable DataTable
}

function Show-Rows {
    param([object[]]$Rows)

    $header = if ($script:ContactLabel -eq 'Email') { 'Email' } else { 'Phone Number' }
    $dt = New-ResultTable -ContactHeader $header

    foreach ($r in $Rows) {
        [void]$dt.Rows.Add(
            $r.'Timestamp (UTC)',
            $r.Activity,
            $r.Status,
            $r.'Status Reason',
            $r.Contact,
            $r.'Correlation ID'
        )
    }

    $grid.DataSource = $dt
}

function Update-FilterColumns {
    # Rebuild the filter column list once after a query (not during filtering).
    $header = if ($script:ContactLabel -eq 'Email') { 'Email' } else { 'Phone Number' }
    $cboFilterCol.Items.Clear()
    [void]$cboFilterCol.Items.AddRange(@('All Columns', 'Timestamp (UTC)', 'Activity', 'Status', 'Status Reason', $header, 'Correlation ID'))
    $cboFilterCol.SelectedIndex = 0
}

function Update-Filter {
    $text = $txtFilter.Text.Trim()
    if (-not $text) { Show-Rows -Rows $script:AllRows; return }

    $col = [string]$cboFilterCol.SelectedItem
    $filtered = $script:AllRows | Where-Object {
        if ($col -and $col -ne 'All Columns') {
            $map = @{
                'Timestamp (UTC)' = $_.'Timestamp (UTC)'
                'Activity'        = $_.Activity
                'Status'          = $_.Status
                'Status Reason'   = $_.'Status Reason'
                'Email'           = $_.Contact
                'Phone Number'    = $_.Contact
                'Correlation ID'  = $_.'Correlation ID'
            }
            ([string]$map[$col]) -like "*$text*"
        }
        else {
            ("$($_.'Timestamp (UTC)') $($_.Activity) $($_.Status) $($_.'Status Reason') $($_.Contact) $($_.'Correlation ID')") -like "*$text*"
        }
    }
    Show-Rows -Rows @($filtered)
    Set-Status ("Filter applied: {0} of {1} rows match." -f @($filtered).Count, $script:AllRows.Count)
}

# ---------------------------------------------------------------- handlers ---

$rbCustom.Add_CheckedChanged({
    $dtpFrom.Enabled = $rbCustom.Checked
    $dtpTo.Enabled   = $rbCustom.Checked
    $cboPreset.Enabled = -not $rbCustom.Checked
})

$btnSignIn.Add_Click({
    try {
        Set-Status 'Signing in...'
        $params = @{ Scopes = @('AuditLog.Read.All', 'Directory.Read.All'); NoWelcome = $true }
        if ($txtTenant.Text.Trim()) { $params.TenantId = $txtTenant.Text.Trim() }
        Connect-MgGraph @params -ErrorAction Stop | Out-Null

        $ctx = Get-MgContext
        $lblAccount.Text = "Signed in: $($ctx.Account)  [$($ctx.TenantId)]"
        $lblAccount.ForeColor = [System.Drawing.Color]::ForestGreen
        $btnQuery.Enabled = $true
        $btnSignOut.Enabled = $true
        $btnSignIn.Enabled = $false
        Set-Status 'Signed in. Choose options and query.'
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Sign-in failed:`n$($_.Exception.Message)", 'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        Set-Status 'Sign-in failed.'
    }
})

$btnSignOut.Add_Click({
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
    $lblAccount.Text = 'Not signed in.'
    $lblAccount.ForeColor = [System.Drawing.Color]::Firebrick
    $btnQuery.Enabled = $false
    $btnSignOut.Enabled = $false
    $btnSignIn.Enabled = $true
    Set-Status 'Signed out.'
})

$btnQuery.Add_Click({
    try {
        $btnQuery.Enabled = $false
        $btnExport.Enabled = $false
        $grid.DataSource = $null
        $script:AllRows = @()

        # Mode + activities
        $mode = if ($rbPhone.Checked) { 'Phone' } else { 'Email' }
        $script:ContactLabel = $mode
        $activities = $script:ActivityMap[$mode]

        # Date window -> UTC ISO8601
        if ($rbCustom.Checked) {
            # Picker values are entered as UTC to match the UTC-displayed timestamps.
            $startUtc = [DateTime]::SpecifyKind($dtpFrom.Value, 'Utc')
            $endUtc   = [DateTime]::SpecifyKind($dtpTo.Value, 'Utc')
        }
        else {
            $endUtc = [DateTime]::UtcNow
            switch ($cboPreset.SelectedItem) {
                'Last 24 hours' { $startUtc = $endUtc.AddHours(-24) }
                'Last 3 days'   { $startUtc = $endUtc.AddDays(-3) }
                'Last 7 days'   { $startUtc = $endUtc.AddDays(-7) }
                default         { $startUtc = $endUtc.AddHours(-24) }
            }
        }
        if ($endUtc -le $startUtc) {
            [System.Windows.Forms.MessageBox]::Show('The "To" date must be after the "From" date.', 'Invalid range',
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            $btnQuery.Enabled = $true
            return
        }

        $startZ = $startUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
        $endZ   = $endUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')

        $activityClause = ($activities | ForEach-Object { "activityDisplayName eq '$_'" }) -join ' or '
        $filter = "($activityClause) and activityDateTime ge $startZ and activityDateTime le $endZ"
        if ($chkFailures.Checked) { $filter += " and (result eq 'failure' or result eq 'timeout')" }
        $encoded = [uri]::EscapeDataString($filter)
        $uri = "https://graph.microsoft.com/beta/auditLogs/directoryAudits?`$filter=$encoded&`$top=100"

        # Page through results.
        $collected = New-Object System.Collections.Generic.List[object]
        $page = 0
        do {
            $page++
            Set-Status ("Querying page {0} ({1} records so far)..." -f $page, $collected.Count)
            $resp = Invoke-GraphWithRetry -Uri $uri

            foreach ($rec in @($resp.value)) {
                $ts = $null
                if ($rec.activityDateTime) {
                    try   { $ts = ([DateTime]$rec.activityDateTime).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') }
                    catch { $ts = [string]$rec.activityDateTime }
                }
                $contact = Get-ContactValue -Record $rec -Mode $mode
                $collected.Add([PSCustomObject]@{
                    'Timestamp (UTC)' = $ts
                    'Activity'        = $rec.activityDisplayName
                    'Status'          = $rec.result
                    'Status Reason'   = $rec.resultReason
                    'Contact'         = $contact
                    'Correlation ID'  = $rec.correlationId
                })
            }

            $uri = $resp.'@odata.nextLink'
        } while ($uri)

        $script:AllRows = $collected.ToArray()
        Update-FilterColumns
        $txtFilter.Clear()
        Show-Rows -Rows $script:AllRows
        $btnExport.Enabled = ($script:AllRows.Count -gt 0)
        Set-Status ("Done. {0} record(s) returned for {1} verification between {2} and {3} UTC." -f `
            $script:AllRows.Count, $mode, $startZ, $endZ)
    }
    catch {
        $detail = "Query failed:`n$($_.Exception.Message)`n`nAt: $($_.InvocationInfo.ScriptLineNumber)`n$($_.ScriptStackTrace)"
        [System.Windows.Forms.MessageBox]::Show($detail, 'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        Set-Status 'Query failed.'
    }
    finally {
        $btnQuery.Enabled = $true
    }
})

$txtFilter.Add_TextChanged({ Update-Filter })
$cboFilterCol.Add_SelectedIndexChanged({ if ($cboFilterCol.Focused -and $txtFilter.Text) { Update-Filter } })
$btnClearFilter.Add_Click({ $txtFilter.Clear(); Show-Rows -Rows $script:AllRows; Set-Status 'Filter cleared.' })

$btnExport.Add_Click({
    if (-not $grid.DataSource) { return }
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = 'CSV files (*.csv)|*.csv'
    $dlg.FileName = "B2C_$($script:ContactLabel)_Verification_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $dt = [System.Data.DataTable]$grid.DataSource
            $rows = foreach ($row in $dt.Rows) {
                $obj = [ordered]@{}
                foreach ($col in $dt.Columns) { $obj[$col.ColumnName] = $row[$col.ColumnName] }
                [PSCustomObject]$obj
            }
            $rows | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
            Set-Status ("Exported {0} row(s) to {1}" -f $dt.Rows.Count, $dlg.FileName)
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Export failed:`n$($_.Exception.Message)", 'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    }
})

# ------------------------------------------------------------------- run ----
[void]$form.ShowDialog()
$form.Dispose()
