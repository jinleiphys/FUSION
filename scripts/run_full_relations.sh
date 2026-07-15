#!/bin/bash
# FUSION L3-semantic full run, gated to the DeepSeek off-peak window
# (00:30-08:30 Beijing). Self-looping + resumable: classify all citing papers
# across as many windows as needed, then inject Related work sections once done.
# Arm once: nohup caffeinate -is bash scripts/run_full_relations.sh & disown
set -u
cd "$(dirname "$0")/.."
PY=/Users/jinlei/anaconda3/bin/python
REL=kb-wiki/relations.tsv
LOG=kb-wiki/relations-run-$(date +%Y%m%d-%H%M).log

minutes_now() { echo $((10#$(date +%H) * 60 + 10#$(date +%M))); }
todo_count() { $PY scripts/kb_relations.py full --workers 1 2>&1 | grep -o '[0-9]* to go' | grep -o '[0-9]*' | head -1; }

echo "armed $(date)" >> "$LOG"
while :; do
  left=$(todo_count 2>/dev/null || echo 1)
  [ "${left:-1}" -eq 0 ] && break
  while :; do
    hm=$(minutes_now)
    if [ "$hm" -ge 30 ] && [ "$hm" -lt 505 ]; then break; fi
    sleep 60
  done
  echo "window open $(date), $left to go" >> "$LOG"
  $PY scripts/kb_relations.py full --workers 40 >> "$LOG" 2>&1 &
  PID=$!
  while kill -0 "$PID" 2>/dev/null; do
    hm=$(minutes_now)
    if [ "$hm" -ge 505 ] && [ "$hm" -lt 1200 ]; then
      echo "08:25 deadline, stopping (resume next window)" >> "$LOG"
      kill "$PID"; break
    fi
    sleep 120
  done
  wait "$PID" 2>/dev/null
  echo "window closed $(date)" >> "$LOG"
  sleep 300
done

echo "classification complete $(date), injecting Related work sections" >> "$LOG"
$PY scripts/kb_relations.py inject --relations-tsv "$REL" >> "$LOG" 2>&1
echo "ALL DONE $(date)" >> "$LOG"
