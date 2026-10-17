#!/bin/zsh
# Makes the Notch film and the hero loop (see docs/notch-film.md).
#
#   film/make-film.sh build             build the director from the app's sources
#   film/make-film.sh preview out.png   render the app's snapshot board with the film's copies
#   film/make-film.sh record film|hero  record one take (takes over the screen for about a minute)
#   film/make-film.sh edit              cut, crop and encode both into apps/web/public/video
#
# Recording quits the installed Claude Notch (its rings and hotkeys would sit on top of the
# director's) and reopens it afterwards. Run it from a terminal with Screen Recording and
# Accessibility permission, and leave the Mac alone while a take runs.
set -euo pipefail
cd "${0:A:h}/.."
NOTCH=$PWD
WORK=$NOTCH/.build/film
PKG=$WORK/package
APP="$WORK/Notch Film.app"
BIN="$APP/Contents/MacOS/NotchFilm"
FONTS=${NOTCH:h}/web/node_modules/@fontsource
VIDEO=${NOTCH:h}/web/public/video
TAKES=$WORK/takes
# Tags the frames themselves: ffmpeg leaves primaries and transfer unset otherwise.
TAG_709=setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv

build() {
  rm -rf $PKG/Sources
  mkdir -p $PKG/Sources/NotchFilm
  for file in Sources/ClaudeNotch/*.swift; do
    [[ ${file:t} == App.swift ]] || cp $file $PKG/Sources/NotchFilm/
  done
  cp film/Sources/*.swift $PKG/Sources/NotchFilm/
  cat > $PKG/Package.swift <<SWIFT
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NotchFilm",
    platforms: [.macOS(.v26)],
    dependencies: [.package(path: "$NOTCH")],
    targets: [
        .executableTarget(name: "NotchFilm", dependencies: [.product(name: "UsageCore", package: "notch")]),
    ]
)
SWIFT
  swift build -c release --package-path $PKG
  local version=$(sed -n 's/.*CFBundleShortVersionString<\/key><string>\([^<]*\)<.*/\1/p' scripts/build-app.sh)
  rm -rf $APP
  mkdir -p "$APP/Contents/MacOS"
  cp $PKG/.build/release/NotchFilm $BIN
  cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.godzillaaa.notch-film</string>
  <key>CFBundleName</key><string>Notch Film</string>
  <key>CFBundleExecutable</key><string>NotchFilm</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
  codesign --force --sign - "$APP"
  echo "Built $APP"
}

preview() {
  $BIN --fonts $FONTS --preview ${1:A}
}

record() {
  local take=$1
  mkdir -p $TAKES
  local geometry=(${(s: :)$($BIN --geometry)})
  local x=$geometry[1] y=$geometry[2] w=$geometry[3] h=$geometry[4]
  local installed=0
  if pgrep -x ClaudeNotch >/dev/null; then
    installed=1
    pkill -x ClaudeNotch
    sleep 1
  fi
  # RGB from the screen, converted once to BT.709 and kept at a high bitrate for the edit.
  ffmpeg -hide_banner -loglevel error -nostdin -y \
    -f avfoundation -capture_cursor 1 -framerate 60 -pixel_format bgr0 -i "Capture screen 0:none" \
    -vf "crop=$w:$h:$x:$y,scale=out_color_matrix=bt709:out_range=tv,format=yuv420p,$TAG_709" \
    -fps_mode cfr -r 60 -c:v h264_videotoolbox -b:v 120M -g 60 \
    -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
    $TAKES/$take.mov &
  local recorder=$!
  sleep 2
  $BIN --take $take --fonts $FONTS || true
  sleep 0.5
  kill -INT $recorder
  wait $recorder || true
  if (( installed )); then open "$HOME/Applications/Claude Notch.app"; fi
  echo "Recorded $TAKES/$take.mov"
}

# The start of each white marker the director flashes outside the film's crop, in seconds.
marks() {
  local file=$1 h=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 $1)
  ffmpeg -hide_banner -nostdin -i $file -an \
    -vf "crop=32:32:16:$((h - 48)),signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" \
    -f null - 2>/dev/null \
    | awk '/pts_time/ { split($0, a, "pts_time:"); t = a[2] + 0 }
           /YAVG/ { split($0, b, "="); on = (b[2] + 0 > 128); if (on && !was) print t; was = on }'
}

encode() {
  local input=$1 start=$2 length=$3 filter=$4 name=$5 poster_at=$6
  local tagged="$filter,$TAG_709"
  mkdir -p $VIDEO
  ffmpeg -hide_banner -loglevel error -nostdin -y -ss $start -i $input -t $length -an -vf "$tagged" \
    -c:v libx264 -preset slow -crf 20 -profile:v high -pix_fmt yuv420p -movflags +faststart \
    -colorspace bt709 -color_primaries bt709 -color_trc bt709 $VIDEO/$name.mp4
  ffmpeg -hide_banner -loglevel error -nostdin -y -ss $start -i $input -t $length -an -vf "$tagged" \
    -c:v libvpx-vp9 -b:v 0 -crf 34 -row-mt 1 -deadline good -cpu-used 2 -pix_fmt yuv420p \
    -colorspace bt709 -color_primaries bt709 -color_trc bt709 $VIDEO/$name.webm
  ffmpeg -hide_banner -loglevel error -nostdin -y -ss $(( start + poster_at )) -i $input -frames:v 1 \
    -vf "${filter%%,fade*}" -q:v 2 $VIDEO/$name-poster.jpg
  ls -la $VIDEO/$name.*  $VIDEO/$name-poster.jpg
}

edit() {
  # The film: from just before the title to the end card's last frame. Its marks are at
  # 0.5 s and 60.0 s of the take.
  local film=($(marks $TAKES/film.mov))
  echo "film marks: $film"
  local start=$(( film[1] + 0.3 )) length=59.2
  encode $TAKES/film.mov $start $length "crop=1920:1080:64:0,fade=t=out:st=$(( length - 0.6 )):d=0.6" notch-film 12.6

  # The hero: the second of three identical cycles, mark to mark, so it loops seamlessly.
  local hero=($(marks $TAKES/hero.mov))
  echo "hero marks: $hero"
  local w=1600 h=900
  encode $TAKES/hero.mov $hero[2] $(( hero[3] - hero[2] )) "crop=$w:$h:$(( (2048 - w) / 2 )):0" notch-hero 0
}

case ${1:-} in
  build) build ;;
  preview) preview ${2:?a png path} ;;
  record) record ${2:?film or hero} ;;
  marks) marks $TAKES/${2:?film or hero}.mov ;;
  edit) edit ;;
  *) sed -n '2,11p' $0; exit 1 ;;
esac
