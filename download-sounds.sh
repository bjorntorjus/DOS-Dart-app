#!/bin/bash
# 🎯 Dart App - Meme Sound Downloader
# Run this script from the project root (where pubspec.yaml is)
# Usage: bash download-sounds.sh

BASE="assets/sounds"
COUNT=0
FAIL=0

download() {
  local url="$1"
  local dest="$2"
  local name="$(basename "$dest")"

  # Create directory if needed
  mkdir -p "$(dirname "$dest")"

  echo -n "  Downloading $name ... "
  if curl -sL --fail --max-time 30 \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
    -H "Referer: https://www.myinstants.com/" \
    -o "$dest" "$url"; then
    local size=$(du -h "$dest" | cut -f1)
    echo "OK ($size)"
    COUNT=$((COUNT + 1))
  else
    echo "FAILED"
    rm -f "$dest"
    FAIL=$((FAIL + 1))
  fi
}

echo "============================================"
echo "  🎯 Dart App Sound Downloader"
echo "============================================"
echo ""

# ═══════════════════════════════════════════
# SYSTEM SOUNDS (root level)
# ═══════════════════════════════════════════
echo "📢 System Sounds"
download "https://www.myinstants.com/media/sounds/final-fantasy-vii-victory-fanfare-1.mp3" \
  "$BASE/win.mp3"
download "https://www.myinstants.com/media/sounds/erro.mp3" \
  "$BASE/bust.mp3"
download "https://www.myinstants.com/media/sounds/cha-ching-money.mp3" \
  "$BASE/checkout.mp3"
download "https://www.myinstants.com/media/sounds/oh-baby-a-triple.mp3" \
  "$BASE/triple.mp3"
download "https://www.myinstants.com/media/sounds/nice-meem.MP3" \
  "$BASE/nice.mp3"
echo ""

# ═══════════════════════════════════════════
# X01 POSITIVE (end of round) — round score >= 100
# ═══════════════════════════════════════════
echo "🟢 X01 Positive"
download "https://www.myinstants.com/media/sounds/6_1Njp68r.mp3" \
  "$BASE/x01/positive/end of round/owen-wilson-wow.mp3"
download "https://www.myinstants.com/media/sounds/mlg-airhorn.mp3" \
  "$BASE/x01/positive/end of round/mlg-air-horn.mp3"
download "https://www.myinstants.com/media/sounds/another-one_dPvHt2Z.mp3" \
  "$BASE/x01/positive/end of round/dj-khaled-another-one.mp3"
download "https://www.myinstants.com/media/sounds/hes-on-fire_h9DW1bE.mp3" \
  "$BASE/x01/positive/end of round/nba-jam-hes-on-fire.mp3"
echo ""

# ═══════════════════════════════════════════
# X01 NEGATIVE (end of round) — round score < 10
# ═══════════════════════════════════════════
echo "🔴 X01 Negative (extras)"
download "https://www.myinstants.com/media/sounds/vine-boom.mp3" \
  "$BASE/x01/negative/end of round/vine-boom.mp3"
download "https://www.myinstants.com/media/sounds/curb-your-enthusiasm.mp3" \
  "$BASE/x01/negative/end of round/curb-your-enthusiasm.mp3"
download "https://www.myinstants.com/media/sounds/jixaw-metal-pipe-falling-sound.mp3" \
  "$BASE/x01/negative/end of round/metal-pipe-falling.mp3"
echo ""

# ═══════════════════════════════════════════
# MISS — miss button pressed
# ═══════════════════════════════════════════
echo "🎯 Miss"
download "https://www.myinstants.com/media/sounds/sadtrombone.swf.mp3" \
  "$BASE/miss/sad-trombone.mp3"
download "https://www.myinstants.com/media/sounds/roblox-death-sound_1.mp3" \
  "$BASE/miss/roblox-oof.mp3"
download "https://www.myinstants.com/media/sounds/the-price-is-right-losing-horn.mp3" \
  "$BASE/miss/price-is-right-losing-horn.mp3"
echo ""

# ═══════════════════════════════════════════
# KILLER HIT — player loses a life
# ═══════════════════════════════════════════
echo "💀 Killer Hit"
download "https://www.myinstants.com/media/sounds/wilhelmscream.mp3" \
  "$BASE/killer/hit/wilhelm-scream.mp3"
download "https://www.myinstants.com/media/sounds/tindeck_1.mp3" \
  "$BASE/killer/hit/mgs-alert.mp3"
download "https://www.myinstants.com/media/sounds/steve-old-hurt-sound_3cQdSVW.mp3" \
  "$BASE/killer/hit/minecraft-hurt.mp3"
echo ""

# ═══════════════════════════════════════════
# KILLER DEATH — player eliminated
# ═══════════════════════════════════════════
echo "☠️  Killer Death"
download "https://www.myinstants.com/media/sounds/my-movie-3.mp3" \
  "$BASE/killer/death/mario-death.mp3"
download "https://www.myinstants.com/media/sounds/dark-souls-you-died-sound-effect_hm5sYFG.mp3" \
  "$BASE/killer/death/dark-souls-you-died.mp3"
download "https://www.myinstants.com/media/sounds/gta-v-death-sound-effect-102.mp3" \
  "$BASE/killer/death/gta-wasted.mp3"
download "https://www.myinstants.com/media/sounds/finish-him.mp3" \
  "$BASE/killer/death/finish-him.mp3"
download "https://www.myinstants.com/media/sounds/stationary-kill_gDwMUvN.mp3" \
  "$BASE/killer/death/among-us-kill.mp3"
echo ""

# ═══════════════════════════════════════════
# OFFENSIVE — miss/offensive
# ═══════════════════════════════════════════
echo "🔞 Offensive"
download "https://www.myinstants.com/media/sounds/fart-meme-sound_qo90QRs.mp3" \
  "$BASE/miss/offensive/fart-sound.mp3"
echo ""

# ═══════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════
echo "============================================"
echo "  ✅ Done! $COUNT downloaded, $FAIL failed"
echo "============================================"
echo ""
echo "Files downloaded to: $BASE/"
echo ""
echo "Still missing (add manually later):"
echo "  - bull.mp3 (bullseye hit)"
echo "  - six_seven.mp3 (6-7 sequence)"
echo "  - cricket/ sounds"
echo "  - halve_it/ sounds"
echo "  - around_the_clock/ sounds"
echo "  - x01/offensive/ sounds"
echo "  - killer/offensive/ sounds"
echo ""
echo "Tip: For cricket/halve_it/around_the_clock, you can"
echo "copy sounds from x01/positive/ and x01/negative/."
