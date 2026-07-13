#!/bin/bash
# FUSION KB full-corpus digestion, gated to the DeepSeek off-peak window
# (00:30-08:30 Beijing). SELF-LOOPING: keeps waiting for the next window and
# resuming (skip-existing) until every id in the list has a page on disk.
# Arm once with: nohup caffeinate -is bash scripts/run_full_digest.sh & disown
set -u
cd "$(dirname "$0")/.."
PY=/Users/jinlei/anaconda3/bin/python
LIST=kb-wiki/paper-list-full.txt
TOTAL=$(wc -l < "$LIST" | tr -d ' ')
LOG=kb-wiki/full-run-$(date +%Y%m%d-%H%M).log

minutes_now() { echo $((10#$(date +%H) * 60 + 10#$(date +%M))); }
pages_done() { find kb-wiki/papers -name "*.md" 2>/dev/null | wc -l | tr -d ' '; }

echo "armed $(date), target $TOTAL, on disk $(pages_done)" >> "$LOG"
while [ "$(pages_done)" -lt "$TOTAL" ]; do
  while :; do
    hm=$(minutes_now)
    if [ "$hm" -ge 30 ] && [ "$hm" -lt 505 ]; then break; fi
    sleep 60
  done
  echo "window open $(date), $(pages_done)/$TOTAL on disk, starting batch" >> "$LOG"
  $PY scripts/digest_paper.py --list "$LIST" --outdir kb-wiki/papers --workers 48 >> "$LOG" 2>&1 &
  PID=$!
  while kill -0 "$PID" 2>/dev/null; do
    hm=$(minutes_now)
    if [ "$hm" -ge 505 ] && [ "$hm" -lt 1200 ]; then
      echo "08:25 deadline, stopping batch (loop will resume next window)" >> "$LOG"
      kill "$PID"
      break
    fi
    sleep 120
  done
  wait "$PID" 2>/dev/null
  echo "window closed $(date); pages on disk: $(pages_done)/$TOTAL" >> "$LOG"
  sleep 300
done
echo "ALL DONE $(date): $(pages_done)/$TOTAL pages" >> "$LOG"
