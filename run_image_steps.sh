#!/usr/bin/env bash
# Image pairing for every criteria step, run SEPARATELY from the register steps.
# Each steps_SDS_img_K config loads the saved population of steps_SDS_K (criteria not
# recomputed) and pairs every child with the mother's images from that pregnancy.
#
# Prerequisite: register steps 0-6 already run (bash run_steps.sh).
#
# Usage (script must be in the repo root):
#   bash run_image_steps.sh            # pair images for all 7 steps, then print the image tables
#   FORCE=1 bash run_image_steps.sh    # re-run steps whose output already exists
#   ONLY="5_multiples 6_parity" bash run_image_steps.sh   # run only these steps
# Afterwards you can re-print without re-running:
#   python image_step_summary.py            (all images)
# Cervix images are the next stage: run_cervix_steps.sh, then image_step_summary.py --img-prefix steps_SDS_img_cervix_
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"
export PYTHONPATH="$REPO_ROOT${PYTHONPATH:+:$PYTHONPATH}"
: "${EHR_EXTRACT_OUTPUTS:?Set EHR_EXTRACT_OUTPUTS first}"

ALL_K="0_base 1_GA 2_live 3_CS 4_induction 5_multiples 6_parity"
# Run only some steps:  ONLY="5_multiples 6_parity" bash run_image_steps.sh
STEPS="${ONLY:-$ALL_K}"
# An output counts as "already there" in either layout:
#   $EHR_EXTRACT_OUTPUTS/<config>/<config>_population_train_and_test.csv   (pipeline default)
#   $EHR_EXTRACT_OUTPUTS/<config>_population_train_and_test.csv            (files moved up one level)
has_output() {
  [[ -f "$EHR_EXTRACT_OUTPUTS/$1/$1_population_train_and_test.csv" || -f "$EHR_EXTRACT_OUTPUTS/$1_population_train_and_test.csv" ]]
}
echo "Checking for existing outputs in: $EHR_EXTRACT_OUTPUTS"


for k in $STEPS; do
  src="$EHR_EXTRACT_OUTPUTS/steps_SDS_${k}_population_train_and_test.csv"
  if [[ ! -f "$src" ]]; then
    echo "Missing $src"
    echo "The image configs read the register-step populations from exactly this path."
    echo "Run the register steps first (bash run_steps.sh) or set EHR_EXTRACT_OUTPUTS to their folder."
    exit 1
  fi
done

for k in $STEPS; do
  s="steps_SDS_img_$k"
  if has_output "$s" && [[ -z "$FORCE" ]]; then
    echo ">>> $s: output exists, skipping (FORCE=1 to re-run)"
  else
    echo ">>> running $s"
    python EHR_extract/extract.py --config-name "$s" ${EXTRACT_OVERRIDES}
  fi
done

echo; echo "################ ALL IMAGES ################"
python image_step_summary.py "$@"
