param([string]$OutputFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'sim/data/telecommand_tx_frames.csv'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$codes = @(Import-Csv (Join-Path $root 'sim/data/telecommand_oc_codes.csv'))
if ($codes.Count -ne 42) { throw 'Need the complete protocol OC1..OC42 table' }
$records = [System.Collections.Generic.List[object]]::new()
$guide = '55' * 48
$tailHex = 'C5C5C5C5C5C5C579'
function Add-Period([string]$Name,[string]$Oc,[string]$Code,[string]$Fmt,[string]$Payload) {
    $frame = "EB90B42E$Fmt$Payload$tailHex"
    $records.Add([pscustomobject]@{
        frame_id=$records.Count+1; case_name=$Name; expected_status='OK';
        oc_no=$Oc; code36_hex=$Code; format_hex=$Fmt; payload_length=$Payload.Length/2;
        preamble_bytes=48; preamble_bits=384;
        preamble_hex=$guide; frame_hex=$frame; wire_hex=$guide+$frame
    })
}
for ($i=0;$i -lt 42;$i++) {
    $oc=$codes[$i]
    if ([int]$oc.oc_no -ne $i+1 -or $oc.code36_hex -notmatch '^[0-9A-F]{9}$') { throw 'Invalid protocol OC table' }
    Add-Period ('OC_{0:D2}' -f ($i+1)) $oc.oc_no $oc.code36_hex '39' ($oc.code36_hex*2)
}
$formats=@('5A','69','96','A5','C9')
$lengths=@(32,64,128,256,512)
for ($i=0;$i -lt 5;$i++) {
    # Synthetic frame-layer data with embedded sync/tail patterns; pad with AA.
    # CRC, descrambling and application-command semantics are not implemented by this deframer.
    $app='EB90146FC5C5C5C5C5C5C579'+$formats[$i]+'01020304050607'
    if ($formats[$i] -eq 'C9') { $app += '55'*48 } # Must not emit another guide event inside payload.
    $payload=$app+('AA'*($lengths[$i]-$app.Length/2))
    Add-Period "SOFTWARE_$($formats[$i])" '' '' $formats[$i] $payload
}
[IO.Directory]::CreateDirectory((Split-Path -Parent $OutputFile)) | Out-Null
$records | Export-Csv -LiteralPath $OutputFile -NoTypeInformation -Encoding utf8
Write-Output "Wrote $($records.Count) complete work periods (42 OC + 5 software formats) to $OutputFile"
