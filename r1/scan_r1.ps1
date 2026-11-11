# scan_r1.ps1 - Tu dong quet mang LAN tim dia chi IP loa Phicomm R1
# Ket qua xuat ra file $env:R1_SCAN_OUT theo dinh dang: STT|IP|MoTa
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-LocalSubnets {
    $subnets = [System.Collections.Generic.List[string]]::new()
    try {
        $adapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -and $_.DefaultIPGateway }
        foreach ($adapter in $adapters) {
            foreach ($ip in $adapter.IPAddress) {
                if ($ip -match '^\d+\.\d+\.\d+\.\d+$' -and $ip -notlike '127.*' -and $ip -notlike '169.254.*') {
                    $p = $ip.Split('.')
                    $sub = "$($p[0]).$($p[1]).$($p[2])"
                    if (-not $subnets.Contains($sub)) {
                        $subnets.Add($sub)
                    }
                }
            }
        }
    } catch {}

    if ($subnets.Count -eq 0) {
        try {
            $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { 
                $_.IPAddress -notlike '127.*' -and 
                $_.IPAddress -notlike '169.254.*' -and 
                $_.InterfaceAlias -notmatch 'Virtual|vEthernet|Loopback' 
            }
            foreach ($a in $addrs) {
                $p = $a.IPAddress.Split('.')
                $sub = "$($p[0]).$($p[1]).$($p[2])"
                if (-not $subnets.Contains($sub)) {
                    $subnets.Add($sub)
                }
            }
        } catch {}
    }

    if ($subnets.Count -eq 0) {
        $subnets.Add("192.168.1")
    }
    return $subnets
}

function Scan-Subnet {
    param([string]$Subnet)

    Write-Host ">> Dang quet dai mang $Subnet.1 -> $Subnet.254..." -ForegroundColor Cyan

    $Candidates = [System.Collections.Generic.List[string]]::new()
    $Tasks5555 = [System.Collections.Generic.List[object]]::new()
    $Tasks8081 = [System.Collections.Generic.List[object]]::new()

    # Quet song song port 5555 va 8081
    1..254 | ForEach-Object {
        $ip = "$Subnet.$_"
        $c5555 = New-Object System.Net.Sockets.TcpClient
        $c8081 = New-Object System.Net.Sockets.TcpClient
        try {
            $ar1 = $c5555.BeginConnect($ip, 5555, $null, $null)
            $Tasks5555.Add([PSCustomObject]@{ IP = $ip; Client = $c5555; AR = $ar1 })
        } catch {}
        try {
            $ar2 = $c8081.BeginConnect($ip, 8081, $null, $null)
            $Tasks8081.Add([PSCustomObject]@{ IP = $ip; Client = $c8081; AR = $ar2 })
        } catch {}
    }

    Start-Sleep -Milliseconds 600

    foreach ($t in $Tasks5555) {
        try {
            if ($t.Client.Connected) {
                if (-not $Candidates.Contains($t.IP)) { $Candidates.Add($t.IP) }
            }
        } catch {}
        finally {
            try { $t.Client.Close() } catch {}
        }
    }

    foreach ($t in $Tasks8081) {
        try {
            if ($t.Client.Connected) {
                if (-not $Candidates.Contains($t.IP)) { $Candidates.Add($t.IP) }
            }
        } catch {}
        finally {
            try { $t.Client.Close() } catch {}
        }
    }

    # Quet tiep port 8080 cho cac IP chua nam trong candidates
    $Tasks8080 = [System.Collections.Generic.List[object]]::new()
    1..254 | ForEach-Object {
        $ip = "$Subnet.$_"
        if (-not $Candidates.Contains($ip)) {
            $c8080 = New-Object System.Net.Sockets.TcpClient
            try {
                $ar3 = $c8080.BeginConnect($ip, 8080, $null, $null)
                $Tasks8080.Add([PSCustomObject]@{ IP = $ip; Client = $c8080; AR = $ar3 })
            } catch {}
        }
    }

    Start-Sleep -Milliseconds 500

    foreach ($t in $Tasks8080) {
        try {
            if ($t.Client.Connected) {
                if (-not $Candidates.Contains($t.IP)) { $Candidates.Add($t.IP) }
            }
        } catch {}
        finally {
            try { $t.Client.Close() } catch {}
        }
    }

    # Kiem tra chi tiet tung candidate de xac dinh dung loa R1
    $Results = [System.Collections.Generic.List[object]]::new()
    foreach ($cand in $Candidates) {
        $p5555 = $false
        $p8080 = $false
        $p8081 = $false

        foreach ($p in 5555, 8081, 8080) {
            $c = New-Object System.Net.Sockets.TcpClient
            try {
                $ar = $c.BeginConnect($cand, $p, $null, $null)
                if ($ar.AsyncWaitHandle.WaitOne(300)) {
                    $c.EndConnect($ar)
                    if ($p -eq 5555) { $p5555 = $true }
                    elseif ($p -eq 8081) { $p8081 = $true }
                    elseif ($p -eq 8080) { $p8080 = $true }
                }
            } catch {}
            finally {
                try { $c.Close() } catch {}
            }
        }

        # Tinh diem uu tien cho candidate
        $score = 0
        if ($p5555) { $score += 10 }
        if ($p8081) { $score += 5 }
        if ($p8080) { $score += 2 }

        # Dieu kien xac dinh loa Phicomm R1:
        # 1. Mo ADB (5555)
        # 2. Hoac mo ca Web AIBox (8081) va R1 Player (8080)
        # 3. Hoac mo Web AIBox (8081)
        if ($p5555 -or ($p8080 -and $p8081) -or $p8081) {
            $portList = @()
            if ($p5555) { $portList += "ADB: 5555" }
            if ($p8081) { $portList += "Web AI Box: 8081" }
            if ($p8080) { $portList += "R1: 8080" }
            $desc = "Phicomm R1 (" + ($portList -join ", ") + ")"
            $Results.Add([PSCustomObject]@{ IP = $cand; Desc = $desc; Score = $score })
        }
    }

    return $Results
}

# --- MAIN ---
$allSpeakers = [System.Collections.Generic.List[object]]::new()
$subnets = Get-LocalSubnets

foreach ($sub in $subnets) {
    $found = Scan-Subnet -Subnet $sub
    foreach ($sp in $found) {
        if (-not ($allSpeakers | Where-Object { $_.IP -eq $sp.IP })) {
            $allSpeakers.Add($sp)
        }
    }
}

# Sap xep theo do uu tien (score cao nhat len dau)
$sortedSpeakers = $allSpeakers | Sort-Object -Property Score -Descending

# Ghi ket qua ra file output de install.bat doc
$outFile = $env:R1_SCAN_OUT
$outputLines = [System.Collections.Generic.List[string]]::new()
$idx = 1
foreach ($sp in $sortedSpeakers) {
    $line = "$idx|$($sp.IP)|$($sp.Desc)"
    $outputLines.Add($line)
    if (-not $outFile) {
        Write-Host "   [$idx] $($sp.IP)  ($($sp.Desc))" -ForegroundColor Green
    }
    $idx++
}

if ($outFile) {
    try {
        [System.IO.File]::WriteAllLines($outFile, $outputLines, [System.Text.Encoding]::ASCII)
    } catch {
        Set-Content -Path $outFile -Value $outputLines -Encoding ASCII
    }
}

if ($sortedSpeakers.Count -eq 0) {
    Write-Host ">> Khong tim thay loa Phicomm R1 trong mang." -ForegroundColor Yellow
    if ($outFile -and -not (Test-Path $outFile)) {
        New-Item -Path $outFile -ItemType File -Force | Out-Null
    }
} else {
    Write-Host ">> Tim thay $(@($sortedSpeakers).Count) loa Phicomm R1." -ForegroundColor Green
}

exit 0
