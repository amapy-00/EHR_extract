#!/usr/bin/env bash
# Run every step config and print a table of cohort sizes.
# Usage (from the repo root):  bash run_steps.sh [extra hydra overrides...]
set -e

# Always run from the repo root (the folder this script is in) and make the
# EHR_extract package importable, so no PYTHONPATH=... is needed on the command line.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"
export PYTHONPATH="$REPO_ROOT${PYTHONPATH:+:$PYTHONPATH}"
STEPS="steps_SDS_0_base steps_SDS_1_GA steps_SDS_2_live steps_SDS_3_CS steps_SDS_4_induction steps_SDS_5_parity steps_SDS_6_multiples"
for s in $STEPS; do
  echo ">>> running $s"
  python EHR_extract/extract.py --config-name "$s" "$@"
done
python - "$EHR_EXTRACT_OUTPUTS" $STEPS <<'PY'
import sys, polars as pl
out, steps = sys.argv[1], sys.argv[2:]
prev = None
print(f"\n{'step':<24}{'children':>10}{'mothers':>10}{'removed':>10}{'% of base':>11}")
base = None
for s in steps:
    df = pl.read_csv(f"{out}/{s}/{s}_population_train_and_test.csv", infer_schema_length=0)
    n, m = df["CPR_BARN"].n_unique(), df["CPR_MOR"].n_unique()
    base = base or n
    removed = "" if prev is None else prev - n
    print(f"{s:<24}{n:>10}{m:>10}{removed:>10}{100*n/base:>10.1f}%")
    prev = n
PY
