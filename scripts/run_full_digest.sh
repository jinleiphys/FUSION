#!/bin/bash
# FUSION KB full-corpus digestion, gated to the DeepSeek off-peak window
# (00:30-08:30 Beijing). Waits for the window, runs the batch at 28 workers,
# hard-stops at 08:25 so no request bills at the standard rate; resumable:
# re-arm the next evening and it skips existing pages.
set -u
cd "$(dirname "$0")/.."
PY=/Users/jinlei/anaconda3/bin/python
LIST=kb-wiki/paper-list-full.txt
LOG=kb-wiki/full-run-$(date +%Y%m%d-%H%M).log

minutes_now() { echo $((10#$(date +%H) * 60 + 10#$(date +%M))); }

echo "armed $(date), waiting for 00:30" >> "$LOG"
while :; do
  hm=$(minutes_now)
  if [ "$hm" -ge 30 ] && [ "$hm" -lt 505 ]; then break; fi
  sleep 60
done

echo "window open $(date), starting batch" >> "$LOG"
$PY scripts/digest_paper.py --list "$LIST" --outdir kb-wiki/papers --workers 28 >> "$LOG" 2>&1 &
PID=$!

while kill -0 "$PID" 2>/dev/null; do
  hm=$(minutes_now)
  if [ "$hm" -ge 505 ] && [ "$hm" -lt 1200 ]; then
    echo "08:25 deadline reached, stopping batch (resume next night)" >> "$LOG"
    kill "$PID"
    break
  fi
  sleep 120
done
wait "$PID" 2>/dev/null
done_count=$(ls kb-wiki/papers 2>/dev/null | wc -l | tr -d ' ')
echo "run ended $(date); pages on disk: $done_count / $(wc -l < "$LIST")" >> "$LOG"
