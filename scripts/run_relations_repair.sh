#!/bin/bash
# FUSION relations repair run, gated to the DeepSeek off-peak window
# (00:30-08:30 Beijing). Two phases, both resumable across windows:
#   1. `full`: re-type citing papers whose rows were re-opened (the 3,181
#      papers classified without context in July, plus papers whose edge set
#      changed in the 2026-08-12 collision-guard rebuild).
#   2. `recheck-contrasts`: focused second pass over every contrasts row,
#      then --apply the verdicts.
# Ends with one Related-work injection.
# Arm once AFTER the citation-graph rebuild + row re-open prep is done:
#   nohup caffeinate -ims bash scripts/run_relations_repair.sh & disown
# (-m keeps the external KINGSTON drive from idle-sleeping mid-batch, the
#  suspected cause of the July hang on exactly these papers.)
set -u
cd "$(dirname "$0")/.."
PY="${FUSION_PY:-$(command -v python3 || command -v python)}"
[ -x "$PY" ] || { echo "no python found; set FUSION_PY=/path/to/python" >&2; exit 1; }
REL=kb-wiki/relations.tsv
LOG=kb-wiki/relations-repair-$(date +%Y%m%d-%H%M).log

minutes_now() { echo $((10#$(date +%H) * 60 + 10#$(date +%M))); }
wait_window() {
  while :; do
    hm=$(minutes_now)
    if [ "$hm" -ge 30 ] && [ "$hm" -lt 505 ]; then break; fi
    sleep 60
  done
}
run_gated() {  # run "$@" inside the window, kill at 08:25, return 0 when it exited by itself
  "$@" >> "$LOG" 2>&1 &
  PID=$!
  while kill -0 "$PID" 2>/dev/null; do
    hm=$(minutes_now)
    if [ "$hm" -ge 505 ] && [ "$hm" -lt 1200 ]; then
      echo "08:25 deadline, stopping (resume next window)" >> "$LOG"
      kill "$PID"; wait "$PID" 2>/dev/null; return 1
    fi
    sleep 120
  done
  wait "$PID" 2>/dev/null
  return 0
}

echo "armed $(date)" >> "$LOG"

# Phase 1: full re-type of re-opened papers
while :; do
  left=$($PY scripts/kb_relations.py full --count-only 2>/dev/null | grep -o '[0-9]*' | head -1)
  [ "${left:-1}" -eq 0 ] && break
  wait_window
  echo "phase1 window open $(date), $left to go" >> "$LOG"
  run_gated $PY scripts/kb_relations.py full --workers 40
  echo "phase1 window closed $(date)" >> "$LOG"
  sleep 300
done
echo "phase1 complete $(date)" >> "$LOG"

# Phase 2: contrasts recheck
while :; do
  left=$($PY scripts/kb_relations.py recheck-contrasts --count-only 2>/dev/null | grep -o '[0-9]*' | head -1)
  [ "${left:-1}" -eq 0 ] && break
  wait_window
  echo "phase2 window open $(date), $left to go" >> "$LOG"
  run_gated $PY scripts/kb_relations.py recheck-contrasts --workers 40
  echo "phase2 window closed $(date)" >> "$LOG"
  sleep 300
done
echo "phase2 complete $(date), applying verdicts" >> "$LOG"
$PY scripts/kb_relations.py recheck-contrasts --apply >> "$LOG" 2>&1

echo "injecting Related work sections" >> "$LOG"
$PY scripts/kb_relations.py inject --relations-tsv "$REL" >> "$LOG" 2>&1
echo "ALL DONE $(date)" >> "$LOG"
