<#
  Lab 3.2 (optional part) - Intune dashboard from Microsoft Graph
  Reads the managed devices (and optionally the discovered versions of one app) through
  Microsoft Graph and writes a single HTML page with charts (Chart.js), then opens it.

  Examples:
    .\Get-IntuneDashboard.ps1
    .\Get-IntuneDashboard.ps1 -App 'Visual C' -OutFile 'C:\Temp\etcX-Dashboard.html'
#>
param(
    [string] $App,
    [string] $OutFile = 'C:\Temp\IntuneDashboard.html'
)

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement)) {
    Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser -Force
}
Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome

# 1. Managed devices - the same data as GET /deviceManagement/managedDevices in Graph Explorer
$devices = Get-MgDeviceManagementManagedDevice -All -Property id, deviceName, userPrincipalName, operatingSystem, osVersion, complianceState, lastSyncDateTime, isEncrypted
$now     = Get-Date
# Days since the last check-in, added to every device (never synced = very old)
$devices = $devices | ForEach-Object {
    $age = if ($_.LastSyncDateTime -and $_.LastSyncDateTime.Year -gt 1) { ($now - $_.LastSyncDateTime).Days } else { 99999 }
    $_ | Add-Member -NotePropertyName AgeDays -NotePropertyValue $age -PassThru
}

function Count-By ($Items, [scriptblock] $Key) {
    @($Items | Group-Object -Property $Key | Sort-Object Count -Descending |
        ForEach-Object { [pscustomobject]@{ label = [string]$_.Name; count = $_.Count } })
}

# 2. Aggregations - one per chart
$compliance = Count-By $devices { $_.ComplianceState }
$os         = Count-By $devices { $_.OperatingSystem }
$windows    = Count-By ($devices | Where-Object OperatingSystem -eq 'Windows') { $_.OsVersion }

$syncBuckets = foreach ($b in @(@{l = '0-1'; min = 0; max = 1}, @{l = '2-7'; min = 2; max = 7},
                                @{l = '8-30'; min = 8; max = 30}, @{l = 'more than 30'; min = 31; max = 100000})) {
    [pscustomobject]@{
        label = $b.l
        count = @($devices | Where-Object { $_.AgeDays -ge $b.min -and $_.AgeDays -le $b.max }).Count
    }
}

$noncompliant = @($devices | Where-Object ComplianceState -eq 'noncompliant' | Sort-Object LastSyncDateTime |
    ForEach-Object { [pscustomobject]@{
        device   = $_.DeviceName
        user     = $_.UserPrincipalName
        os       = "$($_.OperatingSystem) $($_.OsVersion)"
        lastSync = $_.LastSyncDateTime.ToString('yyyy-MM-dd HH:mm') } })

# 3. Optional: versions of one app from the discovered apps (discovered apps)
$appVersions = @()
if ($App) {
    $filter = "contains(displayName,'$($App -replace "'", "''")')"
    $appVersions = @(Get-MgDeviceManagementDetectedApp -Filter $filter -All |
        Sort-Object DeviceCount -Descending |
        ForEach-Object { [pscustomobject]@{ label = "$($_.DisplayName) ($($_.Version))"; count = $_.DeviceCount } })
}

$data = [ordered]@{
    generated    = $now.ToString('yyyy-MM-dd HH:mm')
    total        = @($devices).Count
    compliant    = @($devices | Where-Object ComplianceState -eq 'compliant').Count
    stale        = @($devices | Where-Object AgeDays -gt 7).Count
    unencrypted  = @($devices | Where-Object { -not $_.IsEncrypted }).Count
    compliance   = $compliance
    os           = $os
    windows      = $windows
    sync         = @($syncBuckets)
    noncompliant = $noncompliant
    app          = $App
    appVersions  = $appVersions
}
$json = ConvertTo-Json -InputObject $data -Depth 4 -Compress

# 4. HTML page - the data goes in as JSON, Chart.js draws the charts in the browser
$html = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Intune Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.js"></script>
<style>
  :root {
    --page: #f9f9f7; --surface: #fcfcfb; --ink: #0b0b0b; --ink2: #52514e; --muted: #898781;
    --grid: #e1e0d9; --border: rgba(11,11,11,0.10); --series: #2a78d6;
    --good: #0ca30c; --warning: #fab219; --critical: #d03b3b; --neutral: #c3c2b7;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --page: #0d0d0d; --surface: #1a1a19; --ink: #f0efec; --ink2: #c3c2b7; --muted: #898781;
      --grid: #2c2c2a; --border: rgba(255,255,255,0.10); --series: #3987e5; --neutral: #5a5955;
    }
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--page); color: var(--ink);
         font-family: system-ui, -apple-system, "Segoe UI", sans-serif; }
  main { max-width: 1200px; margin: 0 auto; padding: 24px 16px 40px; }
  header { display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px; }
  h1 { font-size: 22px; margin: 0; }
  .meta { color: var(--ink2); font-size: 13px; }
  .tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin: 20px 0; }
  .tile, .card { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; }
  .tile { padding: 14px 16px; }
  .tile .label { color: var(--ink2); font-size: 13px; }
  .tile .value { font-size: 30px; font-weight: 600; margin-top: 4px; }
  .tile .sub { color: var(--muted); font-size: 12px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(440px, 1fr)); gap: 12px; }
  .card { padding: 14px 16px; }
  .card h2 { font-size: 15px; margin: 0 0 10px; }
  .chart { position: relative; height: 260px; }
  .wide { grid-column: 1 / -1; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th, td { text-align: left; padding: 6px 8px; border-bottom: 1px solid var(--grid); }
  th { color: var(--ink2); font-weight: 600; }
  td.num { font-variant-numeric: tabular-nums; }
  .empty { color: var(--muted); font-size: 13px; }
</style>
</head>
<body>
<main>
  <header>
    <h1>Intune Dashboard</h1>
    <div class="meta" id="meta"></div>
  </header>
  <section class="tiles" id="tiles"></section>
  <section class="grid">
    <div class="card"><h2>Compliance state</h2><div class="chart"><canvas id="compliance"></canvas></div></div>
    <div class="card"><h2>Devices per operating system</h2><div class="chart"><canvas id="os"></canvas></div></div>
    <div class="card"><h2>Days since last check-in</h2><div class="chart"><canvas id="sync"></canvas></div></div>
    <div class="card"><h2>Windows versions</h2><div class="chart"><canvas id="windows"></canvas></div></div>
    <div class="card wide" id="appCard" hidden><h2 id="appTitle"></h2><div class="chart"><canvas id="app"></canvas></div></div>
    <div class="card wide"><h2>Non-compliant devices</h2><div id="list"></div></div>
  </section>
</main>
<script>
const data = __DATA__;
const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

document.getElementById('meta').textContent = `Generated ${data.generated} · ${data.total} devices`;

const pct = data.total ? Math.round(100 * data.compliant / data.total) : 0;
const tiles = [
  ['Managed devices', data.total, ''],
  ['Compliant', `${pct} %`, `${data.compliant} of ${data.total}`],
  ['No check-in for more than 7 days', data.stale, 'devices'],
  ['Not encrypted', data.unencrypted, 'devices']
];
document.getElementById('tiles').innerHTML = tiles.map(([l, v, s]) =>
  `<div class="tile"><div class="label">${esc(l)}</div><div class="value">${esc(v)}</div><div class="sub">${esc(s)}</div></div>`).join('');

Chart.defaults.font.family = 'system-ui, -apple-system, "Segoe UI", sans-serif';
Chart.defaults.color = css('--ink2');
Chart.defaults.borderColor = css('--grid');
Chart.defaults.plugins.legend.labels.boxWidth = 12;

const statusColor = { compliant: '--good', noncompliant: '--critical', inGracePeriod: '--warning', conflict: '--warning', error: '--critical' };

new Chart(document.getElementById('compliance'), {
  type: 'doughnut',
  data: {
    labels: data.compliance.map(x => `${x.label} (${x.count})`),
    datasets: [{ data: data.compliance.map(x => x.count),
                 backgroundColor: data.compliance.map(x => css(statusColor[x.label] || '--neutral')),
                 borderColor: css('--surface'), borderWidth: 2 }]
  },
  options: { maintainAspectRatio: false, cutout: '60%', plugins: { legend: { position: 'right' } } }
});

function bars(id, rows, horizontal) {
  new Chart(document.getElementById(id), {
    type: 'bar',
    data: { labels: rows.map(x => x.label),
            datasets: [{ label: 'Devices', data: rows.map(x => x.count), backgroundColor: css('--series'),
                         borderRadius: 4, maxBarThickness: 36 }] },
    options: {
      maintainAspectRatio: false, indexAxis: horizontal ? 'y' : 'x',
      plugins: { legend: { display: false } },
      scales: {
        [horizontal ? 'x' : 'y']: { beginAtZero: true, ticks: { precision: 0 } },
        [horizontal ? 'y' : 'x']: { grid: { display: false } }
      }
    }
  });
}
bars('os', data.os, false);
bars('sync', data.sync, false);
bars('windows', data.windows, true);

if (data.app) {
  document.getElementById('appCard').hidden = false;
  document.getElementById('appTitle').textContent = `Discovered versions: "${data.app}"`;
  if (data.appVersions.length) bars('app', data.appVersions, true);
  else document.getElementById('app').parentElement.outerHTML = '<p class="empty">No discovered app matches.</p>';
}

document.getElementById('list').innerHTML = data.noncompliant.length
  ? '<table><thead><tr><th>Device</th><th>User</th><th>OS</th><th>Last check-in</th></tr></thead><tbody>' +
    data.noncompliant.map(d => `<tr><td>${esc(d.device)}</td><td>${esc(d.user)}</td><td>${esc(d.os)}</td><td class="num">${esc(d.lastSync)}</td></tr>`).join('') +
    '</tbody></table>'
  : '<p class="empty">All devices are compliant.</p>';
</script>
</body>
</html>
'@

New-Item -Path (Split-Path $OutFile) -ItemType Directory -Force | Out-Null
$html.Replace('__DATA__', $json) | Out-File -FilePath $OutFile -Encoding utf8
Write-Output "Dashboard written to $OutFile"
Start-Process $OutFile
