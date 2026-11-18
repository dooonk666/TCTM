param([string]$InputCsv = '', [string]$OutputDir = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (!$InputCsv) { $InputCsv = Join-Path $root 'sim/data/telecommand_tx_frames.csv' }
if (!$OutputDir) { $OutputDir = Join-Path $root 'sim/data' }
$rows = @(Import-Csv -LiteralPath $InputCsv)
$codes = @(Import-Csv -LiteralPath (Join-Path $root 'sim/data/telecommand_oc_codes.csv'))
if ($rows.Count -ne 47 -or $codes.Count -ne 42) { throw 'Need 42 OC frames and 5 software frames.' }
[IO.Directory]::CreateDirectory($OutputDir) | Out-Null
function Write-Stream([bool]$Quick) {
$selectedIndexes = @(0..46)
$prefix = 'dttl_telecommand'
if ($Quick) { $selectedIndexes = @(0,41,42); $prefix = 'dttl_telecommand_quick' }
$bytes = [Collections.Generic.List[string]]::new()
$metadata = [Collections.Generic.List[string]]::new()
$cases = [Collections.Generic.List[string]]::new()
$sections = [Collections.Generic.List[object]]::new()
$expected = [Collections.Generic.List[object]]::new()
function Add-Section([int]$Id, [int]$Field, [string]$Name, [string]$Hex) {
    if ($Hex -notmatch '^(?:[0-9A-Fa-f]{2})+$') { throw "Invalid hex in $Name" }
    $start = $bytes.Count
    for ($i=0; $i -lt $Hex.Length/2; $i++) {
        if ($i -gt 4095) { throw 'Section exceeds metadata offset width' }
        $bytes.Add($Hex.Substring($i*2,2).ToUpperInvariant())
        $metadata.Add(('{0:X8}' -f (($Id -shl 16) -bor ($Field -shl 12) -bor $i)))
    }
    $sections.Add([pscustomobject]@{
        section=$sections.Count; frame_id=$Id; field=$Name; start_byte=$start;
        start_bit=$start*8; byte_count=$Hex.Length/2; bit_count=$Hex.Length*4;
        end_bit_exclusive=$bytes.Count*8; hex=$Hex.ToUpperInvariant()
    })
}
# Initial half-period timing offset is exercised while this 0101 stream runs.
Add-Section 0 0 'STARTUP_IDLE' ('55'*128)
$wireBytes = 0
for ($r=0; $r -lt $selectedIndexes.Count; $r++) {
    $sourceIndex = $selectedIndexes[$r]
    $row = $rows[$sourceIndex]
    $id = $r+1
    $fmt = $row.format_hex.ToUpperInvariant()
    $length = [int]$row.payload_length
    $frame = $row.frame_hex.ToUpperInvariant()
    $guide = $row.preamble_hex.ToUpperInvariant()
    if ([int]$row.frame_id -ne $sourceIndex+1 -or $row.expected_status -ne 'OK' -or $guide -cne ('55'*48)) {
        throw "Invalid case/preamble at row $($r+1)"
    }
    $lengthMap = @{'39'=9; '5A'=32; '69'=64; '96'=128; 'A5'=256; 'C9'=512}
    if (!$lengthMap.ContainsKey($fmt) -or $lengthMap[$fmt] -ne $length -or
        $frame.Length -ne (13+$length)*2 -or !$frame.StartsWith("EB90B42E$fmt") -or
        !$frame.EndsWith('C5C5C5C5C5C5C579') -or $row.wire_hex -ine ($guide+$frame)) {
        throw "Invalid frame fields in case $id"
    }
    $payload = $frame.Substring(10,$length*2)
    $oc = 0; $code = '000000000'
    if ($sourceIndex -lt 42) {
        $oc=$sourceIndex+1; $code=$codes[$sourceIndex].code36_hex.ToUpperInvariant()
        if ($fmt -ne '39' -or [int]$row.oc_no -ne $oc -or
            [int]$codes[$sourceIndex].oc_no -ne $oc -or $payload -cne ($code*2)) {
            throw "OC table mismatch in case $id"
        }
    } elseif ($fmt -ne @('5A','69','96','A5','C9')[$sourceIndex-42]) { throw 'Wrong software coverage' }
    $start=$bytes.Count
    Add-Section $id 1 'GUIDE' $guide
    Add-Section $id 2 'SYNC' $frame.Substring(0,4)
    Add-Section $id 3 'ADDRESS' $frame.Substring(4,4)
    Add-Section $id 4 'FORMAT' $fmt
    Add-Section $id 5 'PAYLOAD' $payload
    Add-Section $id 6 'TAIL' $frame.Substring($frame.Length-16)
    $frameBytes=$frame.Length/2
    $cases.Add("$id $start 48 $frameBytes $length $fmt $oc $code $($row.case_name)")
    $expected.Add([pscustomobject]@{
        frame_id=$id; source_frame_id=$row.frame_id; case_name=$row.case_name; oc_no=$oc; code36_hex=$code;
        start_byte=$start; start_bit=$start*8; frame_start_bit=($start+48)*8;
        end_bit_exclusive=$bytes.Count*8; preamble_hex=$guide; sync_hex='EB90';
        address_hex='B42E'; format_hex=$fmt; payload_length=$length;
        payload_hex=$payload; tail_hex='C5C5C5C5C5C5C579'; frame_hex=$frame;
        wire_hex=$guide+$frame
    })
    $wireBytes += 48+$frameBytes
    if ($id -lt $selectedIndexes.Count) {
        # Four long, deterministic idle runs, otherwise 16 idle bytes.
        $idleBytes=16
        if ($Quick) {
            if ($id -eq 2) { $idleBytes=128 }
        } elseif ($id -in @(14,28,42,45)) { $idleBytes=256 }
        Add-Section 0 7 'IDLE' ('55'*$idleBytes)
    }
}
Add-Section 0 8 'DRAIN_IDLE' ('55'*16)
if ($bytes.Count -gt 65536) { throw 'Increase TB MAX_BYTES before using this stream' }
[IO.File]::WriteAllLines((Join-Path $OutputDir "${prefix}_bytes.mem"),$bytes)
[IO.File]::WriteAllLines((Join-Path $OutputDir "${prefix}_meta.mem"),$metadata)
[IO.File]::WriteAllLines((Join-Path $OutputDir "${prefix}_cases.txt"),$cases)
[IO.File]::WriteAllLines((Join-Path $OutputDir "${prefix}_config.mem"),@(
    ('{0:X8}' -f $bytes.Count), ('{0:X8}' -f $selectedIndexes.Count), '00000080', '00000010'))
$sections | Export-Csv -LiteralPath (Join-Path $OutputDir "${prefix}_sections.csv") -NoTypeInformation -Encoding utf8
$expected | Export-Csv -LiteralPath (Join-Path $OutputDir "${prefix}_expected.csv") -NoTypeInformation -Encoding utf8
Write-Output "Prepared $prefix stream: $($selectedIndexes.Count) frames, $wireBytes guide/frame bytes, $($bytes.Count) total bytes, $($bytes.Count*8) symbols. No simulation was run."
}
Write-Stream $false
Write-Stream $true
