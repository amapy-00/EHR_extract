#!/usr/bin/env bash
# Cervix filter for every criteria step, starting from the image CSVs already produced
# (steps_SDS_img_<k>_..._population_train_and_test.csv). Nothing else is recomputed.
#
# Usage (script must be in the repo root):
#   bash run_cervix_steps.sh
#   IMG_CSV_DIR=/path/to/with_images bash run_cervix_steps.sh   # if the image CSVs are elsewhere
#   FORCE=1 bash run_cervix_steps.sh                            # re-run steps that already have output
#   ONLY="5_multiples 6_parity" bash run_cervix_steps.sh         # run only these steps
# Results go to $EHR_EXTRACT_OUTPUTS/steps_SDS_img_cervix_<k>_.../
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"
export PYTHONPATH="$REPO_ROOT${PYTHONPATH:+:$PYTHONPATH}"
: "${EHR_EXTRACT_OUTPUTS:?Set EHR_EXTRACT_OUTPUTS first (where the cervix results will be written)}"

OVERRIDE=""
[[ -n "$IMG_CSV_DIR" ]] && OVERRIDE="img_csv_dir=$IMG_CSV_DIR"

# An output counts as "already there" in either layout:
#   $EHR_EXTRACT_OUTPUTS/<config>/<config>_population_train_and_test.csv   (pipeline default)
#   $EHR_EXTRACT_OUTPUTS/<config>_population_train_and_test.csv            (files moved up one level)
has_output() {
  [[ -f "$EHR_EXTRACT_OUTPUTS/$1/$1_population_train_and_test.csv" || -f "$EHR_EXTRACT_OUTPUTS/$1_population_train_and_test.csv" ]]
}
echo "Checking for existing outputs in: $EHR_EXTRACT_OUTPUTS"
ALL_K="0_base 1_GA 2_live 3_CS 4_induction 5_multiples 6_parity"
# Run only some steps:  ONLY="5_multiples 6_parity" bash run_cervix_steps.sh
for k in ${ONLY:-$ALL_K}; do
  s="steps_SDS_img_cervix_$k"
  if has_output "$s" && [[ -z "$FORCE" ]]; then
    echo ">>> $s: output exists, skipping (FORCE=1 to re-run)"
  else
    echo ">>> running $s"
    python EHR_extract/extract.py --config-name "$s" $OVERRIDE ${EXTRACT_OVERRIDES}
  fi
done
echo
echo "Done. Cervix CSVs are in $EHR_EXTRACT_OUTPUTS/steps_SDS_img_cervix_*/"
echo "Summary: python image_step_summary.py --outputs <register-step folder> \\"
echo "           --img-outputs $EHR_EXTRACT_OUTPUTS --img-prefix steps_SDS_img_cervix_"
