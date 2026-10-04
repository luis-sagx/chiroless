#!/usr/bin/env bash
# Falla si la cobertura de la lógica testeable (sin UI/Firebase) es < MIN%.
set -euo pipefail
MIN="${1:-80}"
awk -v min="$MIN" '
  /^SF:/ { f=substr($0,4); keep = (f ~ /^lib\/(models|core\/constants|core\/theme\/app_exceptions)/ || f ~ /transaction_(draft|categories)|local_transaction_parser/) }
  /^LF:/ && keep { lf+=substr($0,4) }
  /^LH:/ && keep { lh+=substr($0,4) }
  END { p=100*lh/lf; printf "coverage %.1f%% (%d/%d), min %d%%\n", p, lh, lf, min; exit (p<min) }
' coverage/lcov.info
