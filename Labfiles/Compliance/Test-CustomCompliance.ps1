<#
.SYNOPSIS
    Runs a custom compliance discovery script locally and evaluates its output against the JSON rules file.

.DESCRIPTION
    Use it on a test client before you upload the files to Intune. The script
    1. runs the discovery script and checks that it returns one line of valid JSON,
    2. checks that every SettingName in the rules file is present in the output,
    3. compares each value with the rule (Operator, DataType, Operand) and shows Compliant / Not compliant.

    Run it elevated in the 64-bit Windows PowerShell host, which matches System context and
    "Run script in 64 bit PowerShell Host = Yes" closest. The local evaluation is an approximation of
    the Intune evaluation, not the Intune service itself.

.EXAMPLE
    PowerShell.exe -ExecutionPolicy Bypass -File .\Test-CustomCompliance.ps1 -ScriptPath .\etcX-Custom-Discovery.ps1 -RulesPath .\etcX-Custom-Rules.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ScriptPath,
    [Parameter(Mandatory)] [string]$RulesPath
)

$ErrorActionPreference = 'Stop'

if (-not [Environment]::Is64BitProcess) {
    Write-Warning 'This is a 32-bit PowerShell host. Registry and System32 paths are redirected.'
}

# 1. Run the discovery script
$raw = & $ScriptPath
$lines = @($raw | Where-Object { "$_".Trim() })
if ($lines.Count -ne 1) {
    Write-Warning "The discovery script returned $($lines.Count) lines. Intune expects exactly one compressed JSON line."
}
$text = ($lines -join '')
Write-Host "Output ($($text.Length) characters):" -ForegroundColor Cyan
Write-Host $text
try { $found = $text | ConvertFrom-Json } catch { throw "The output is not valid JSON: $($_.Exception.Message)" }

# 2. Read the rules
$rules = (Get-Content -LiteralPath $RulesPath -Raw -Encoding UTF8 | ConvertFrom-Json).Rules
if (-not $rules) { throw 'The rules file has no "Rules" array.' }

function ConvertTo-RuleValue([object]$Value, [string]$DataType) {
    switch ($DataType) {
        'Boolean'  { if ($Value -is [bool]) { return $Value }; return [System.Convert]::ToBoolean("$Value") }
        'Int64'    { return [int64]$Value }
        'Double'   { return [double]$Value }
        'DateTime' { return [datetime]$Value }
        'Version'  { $s = "$Value"; if ($s -notmatch '\.') { $s += '.0' }; return [version]$s }
        default    { return [string]$Value }
    }
}

# 3. Evaluate
$result = foreach ($r in $rules) {
    $name = $r.SettingName
    $prop = $found.PSObject.Properties | Where-Object { $_.Name -ceq $name }
    if (-not $prop) {
        [pscustomobject]@{ Setting = $name; Discovered = '<missing>'; Rule = "$($r.Operator) $($r.Operand)"; Result = 'Missing in output' }
        continue
    }
    try {
        $a = ConvertTo-RuleValue $prop.Value $r.DataType
        $b = ConvertTo-RuleValue $r.Operand $r.DataType
        $ok = switch ($r.Operator) {
            'IsEquals'      { $a -eq $b }
            'NotEquals'     { $a -ne $b }
            'GreaterThan'   { $a -gt $b }
            'GreaterEquals' { $a -ge $b }
            'LessThan'      { $a -lt $b }
            'LessEquals'    { $a -le $b }
            default         { throw "Unknown operator $($r.Operator)" }
        }
        $state = if ($ok) { 'Compliant' } else { 'Not compliant' }
    } catch {
        $state = "Error: $($_.Exception.Message)"
    }
    [pscustomobject]@{ Setting = $name; Discovered = $prop.Value; Rule = "$($r.Operator) $($r.Operand) ($($r.DataType))"; Result = $state }
}

$result | Format-Table -AutoSize -Wrap
