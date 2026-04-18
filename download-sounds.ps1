# Dart App - Meme Sound Downloader (PowerShell)
# Run from project root: Right-click -> Run with PowerShell
# Or: powershell -ExecutionPolicy Bypass -File download-sounds.ps1

$base = "assets\sounds"
$count = 0
$fail = 0

function Download-Sound {
    param([string]$url, [string]$dest)
    $name = Split-Path $dest -Leaf
    $dir = Split-Path $dest -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    Write-Host "  Downloading $name ... " -NoNewline
    try {
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            "Referer" = "https://www.myinstants.com/"
        }
        Invoke-WebRequest -Uri $url -OutFile $dest -Headers $headers -TimeoutSec 30
        $size = (Get-Item $dest).Length
        if ($size -gt 0) {
            $kb = [math]::Round($size / 1024, 1)
            Write-Host "OK (${kb}KB)" -ForegroundColor Green
            $script:count++
        } else {
            Write-Host "EMPTY" -ForegroundColor Red
            Remove-Item $dest -Force
            $script:fail++
        }
    } catch {
        Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $dest) { Remove-Item $dest -Force }
        $script:fail++
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Dart App Sound Downloader" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- SYSTEM SOUNDS (root level) ---
Write-Host "System Sounds" -ForegroundColor Yellow
Download-Sound "https://www.myinstants.com/media/sounds/final-fantasy-vii-victory-fanfare-1.mp3" "$base\win.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/erro.mp3" "$base\bust.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/cha-ching-money.mp3" "$base\checkout.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/oh-baby-a-triple.mp3" "$base\triple.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/nice-meem.MP3" "$base\nice.mp3"
Write-Host ""

# --- X01 POSITIVE ---
Write-Host "X01 Positive" -ForegroundColor Yellow
Download-Sound "https://www.myinstants.com/media/sounds/6_1Njp68r.mp3" "$base\x01\positive\end of round\owen-wilson-wow.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/mlg-airhorn.mp3" "$base\x01\positive\end of round\mlg-air-horn.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/another-one_dPvHt2Z.mp3" "$base\x01\positive\end of round\dj-khaled-another-one.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/hes-on-fire_h9DW1bE.mp3" "$base\x01\positive\end of round\nba-jam-hes-on-fire.mp3"
Write-Host ""

# --- X01 NEGATIVE (extras) ---
Write-Host "X01 Negative (extras)" -ForegroundColor Yellow
Download-Sound "https://www.myinstants.com/media/sounds/vine-boom.mp3" "$base\x01\negative\end of round\vine-boom.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/curb-your-enthusiasm.mp3" "$base\x01\negative\end of round\curb-your-enthusiasm.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/jixaw-metal-pipe-falling-sound.mp3" "$base\x01\negative\end of round\metal-pipe-falling.mp3"
Write-Host ""

# --- MISS ---
Write-Host "Miss" -ForegroundColor Yellow
Download-Sound "https://www.myinstants.com/media/sounds/sadtrombone.swf.mp3" "$base\miss\sad-trombone.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/roblox-death-sound_1.mp3" "$base\miss\roblox-oof.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/the-price-is-right-losing-horn.mp3" "$base\miss\price-is-right-losing-horn.mp3"
Write-Host ""

# --- KILLER HIT ---
Write-Host "Killer Hit" -ForegroundColor Yellow
Download-Sound "https://www.myinstants.com/media/sounds/wilhelmscream.mp3" "$base\killer\hit\wilhelm-scream.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/tindeck_1.mp3" "$base\killer\hit\mgs-alert.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/steve-old-hurt-sound_3cQdSVW.mp3" "$base\killer\hit\minecraft-hurt.mp3"
Write-Host ""

# --- KILLER DEATH ---
Write-Host "Killer Death" -ForegroundColor Yellow
Download-Sound "https://www.myinstants.com/media/sounds/my-movie-3.mp3" "$base\killer\death\mario-death.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/dark-souls-you-died-sound-effect_hm5sYFG.mp3" "$base\killer\death\dark-souls-you-died.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/gta-v-death-sound-effect-102.mp3" "$base\killer\death\gta-wasted.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/finish-him.mp3" "$base\killer\death\finish-him.mp3"
Download-Sound "https://www.myinstants.com/media/sounds/stationary-kill_gDwMUvN.mp3" "$base\killer\death\among-us-kill.mp3"
Write-Host ""

# --- OFFENSIVE ---
Write-Host "Offensive" -ForegroundColor Yellow
Download-Sound "https://www.myinstants.com/media/sounds/fart-meme-sound_qo90QRs.mp3" "$base\miss\offensive\fart-sound.mp3"
Write-Host ""

# --- SUMMARY ---
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Done! $count downloaded, $fail failed" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Still needed (add manually):"
Write-Host "  - bull.mp3 (bullseye hit)"
Write-Host "  - six_seven.mp3 (6-7 sequence)"
Write-Host "  - cricket/ halve_it/ around_the_clock/ sounds"
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
