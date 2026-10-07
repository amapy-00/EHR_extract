#!/usr/bin/env bash
# Run every step config and print a table of cohort sizes.
# Usage (from the repo root):  bash run_steps.sh [extra hydra overrides...]
# Steps whose output already exists are skipped; FORCE=1 bash run_steps.sh re-runs everything.
# Only some steps: ONLY="steps_SDS_5_multiples steps_SDS_6_parity" bash run_steps.sh
set -e

# Always run from the repo root (the folder this script is in) and make the
# EHR_extract package importable, so no PYTHONPATH=... is needed on the command line.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"
export PYTHONPATH="$REPO_ROOT${PYTHONPATH:+:$PYTHONPATH}"
: "${EHR_EXTRACT_OUTPUTS:?Set EHR_EXTRACT_OUTPUTS first}"
ALL_STEPS="steps_SDS_0_base steps_SDS_1_GA steps_SDS_2_live steps_SDS_3_CS steps_SDS_4_induction steps_SDS_5_multiples steps_SDS_6_parity"
# Run only some steps:  ONLY="steps_SDS_5_multiples steps_SDS_6_parity" bash run_steps.sh
RUN_STEPS="${ONLY:-$ALL_STEPS}"
# An output counts as "already there" in either layout:
#   $EHR_EXTRACT_OUTPUTS/<config>/<config>_population_train_and_test.csv   (pipeline default)
#   $EHR_EXTRACT_OUTPUTS/<config>_population_train_and_test.csv            (files moved up one level)
has_output() {
  [[ -f "$EHR_EXTRACT_OUTPUTS/$1/$1_population_train_and_test.csv" || -f "$EHR_EXTRACT_OUTPUTS/$1_population_train_and_test.csv" ]]
}
echo "Checking for existing outputs in: $EHR_EXTRACT_OUTPUTS"

for s in $RUN_STEPS; do
  if has_output "$s" && [[ -z "$FORCE" ]]; then
    echo ">>> $s: output exists, skipping (FORCE=1 to re-run)"
  else
    echo ">>> running $s"
    python EHR_extract/extract.py --config-name "$s" "$@"
  fi
done
python - "$EHR_EXTRACT_OUTPUTS" $ALL_STEPS <<'PY'
import sys, polars as pl
out, steps = sys.argv[1], sys.argv[2:]
prev = None
print(f"\n{'step':<24}{'children':>10}{'mothers':>10}{'removed':>10}{'% of base':>11}")
base = None
for s in steps:
    import os
    p = f"{out}/{s}/{s}_population_train_and_test.csv"
    if not os.path.isfile(p):
        p = f"{out}/{s}_population_train_and_test.csv"
    df = pl.read_csv(p, infer_schema_length=0)
    n, m = df["CPR_BARN"].n_unique(), df["CPR_MOR"].n_unique()
    base = base or n
    removed = "" if prev is None else prev - n
    print(f"{s:<24}{n:>10}{m:>10}{removed:>10}{100*n/base:>10.1f}%")
    prev = n
PY
