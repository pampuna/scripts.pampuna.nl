#!/bin/bash
f="$1"
r="\e[31m" g="\e[32m" n="\e[0m"

# Verify the file exists and is a PNG
[[ -f "$f" ]]||{ echo -e "${r}[!] File not found${n}";exit 1; }
sig=$(head -c8 "$f" | xxd -p -c8)
[[ "$sig" = "89504e470d0a1a0a" ]] || { echo -e "${r}[!] Not a PNG image${n}"; exit 1; }

# First look for any unknown ancillary chunks
known=(IHDR PLTE IDAT IEND tEXt zTXt iTXt bKGD cHRM gAMA hIST iCCP pHYs sBIT sPLT sRGB tIME)
offset=8 unknown=() unknown_total=0
while :; do
  lenhex=$(xxd -p -s $offset -l4 "$f")||break
  ((len=16#$lenhex))
  type=$(xxd -p -s $((offset+4)) -l4 "$f"|xxd -r -p)
  [[ $type =~ ^[a-zA-Z]{4}$ ]]||break
  if [[ ${type:0:1} =~ [a-z] ]]&&! [[ " ${known[*]} " =~ " $type " ]];then
    unknown+=("$type")
    ((unknown_total+=len))
  fi
  ((offset+=len+12))
  [[ $type == IEND ]]&&break
done

# Output ancillary chunk findings
if ((${#unknown[@]}));then echo -e "${r}[!] Unknown ancillary chunks:${n} ${unknown[*]}"
else echo -e "${g}[+] No unknown ancillary chunks${n}";fi
echo "[i] Total unknown ancillary chunk data length: $unknown_total bytes"

# The following code reads and decodes the PNG IHDR chunk to extract image width, height, bit depth, and color type, determines the number of channels.
# It then calculates the estimated uncompressed image size in bytes, and gets the actual file size for comparison.
# ihdr=IHDR data bytes, w=width, h=height, b=bit depth, ct=color type, c=channels, raw=raw image size bytes, real=file size bytes
ihdr=$(dd if="$f" bs=1 skip=16 count=13 2>/dev/null|xxd -p)
w=$((16#${ihdr:0:8}))
h=$((16#${ihdr:8:8}))
b=$((16#${ihdr:16:2}))
ct=$((16#${ihdr:18:2}))

# Determine channels based on color type per PNG spec
case $ct in
  0) c=1 ;;  # Grayscale
  2) c=3 ;;  # Truecolor RGB
  3) c=1 ;;  # Indexed color
  4) c=2 ;;  # Grayscale + alpha
  6) c=4 ;;  # Truecolor + alpha RGBA
  *) c=4 ;;  # Assume 4 for unknown types as a safe fallback
esac

raw=$((w*h*c*b/8))
real=$(stat -c%s "$f")
raw=$(( w * h * c * b / 8 ))  # estimated uncompressed image size in bytes
real=$(stat -c%s "$f")        # actual file size in bytes

echo "[i] Image: ${w}x${h}, bit-depth:$b, color-type:$ct, channels:$c"
echo "[i] Raw image size (uncompressed): $raw bytes"
echo "[i] Actual file size: $real bytes"

# Estimate if the file is larger than expected based on the image data
threshold=2
max_allowed=$((raw*threshold))
echo "[i] Max allowed file size (raw * $threshold): $max_allowed bytes"
if (( real > max_allowed ));then
  echo -e "${r}[!] Warning: File unexpectedly large, possible hidden data${n}"
else
  echo -e "${g}[+] File size seems OK${n}"
fi

# Estimate if the ancillary chunk data is relatively large
ratio_unknown=$(awk "BEGIN { printf \"%.2f\", $unknown_total/$raw }")
echo "[i] Unknown ancillary data / raw image size ratio: $ratio_unknown"
if awk "BEGIN { exit !($ratio_unknown > 0.2) }"; then
  echo -e "${r}[!] Warning: Unknown ancillary chunks occupy >20% of raw image size${n}"
fi
