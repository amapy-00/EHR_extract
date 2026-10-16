#!/usr/bin/env bash
# Register steps (no images): criteria 1-6 applied one by one (6 = first birth / parity).
# Dataset: new   Results: /home/am/Documents/output_cohort/filtering_steps_SDS/new
# Run from anywhere:  bash run_steps_new.sh   (this script must be in the repo root, next to EHR_extract/)
# Existing results with the same names are OVERWRITTEN.
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"                      # repo root
export PYTHONPATH="$PWD"
export EHR_EXTRACT_CONFIGS="${EHR_EXTRACT_CONFIGS:-$PWD/configs}"
mkdir -p "/home/am/Documents/output_cohort/filtering_steps_SDS/new"

echo ">>> steps_SDS_0_base_new"
python EHR_extract/extract.py --config-name steps_SDS_0_base_new

echo ">>> steps_SDS_1_GA_new"
python EHR_extract/extract.py --config-name steps_SDS_1_GA_new

echo ">>> steps_SDS_2_live_new"
python EHR_extract/extract.py --config-name steps_SDS_2_live_new

echo ">>> steps_SDS_3_CS_new"
python EHR_extract/extract.py --config-name steps_SDS_3_CS_new

echo ">>> steps_SDS_4_induction_new"
python EHR_extract/extract.py --config-name steps_SDS_4_induction_new

echo ">>> steps_SDS_5_multiples_new"
python EHR_extract/extract.py --config-name steps_SDS_5_multiples_new

echo ">>> steps_SDS_6_parity_new"
python EHR_extract/extract.py --config-name steps_SDS_6_parity_new

echo "Done. Results in: /home/am/Documents/output_cohort/filtering_steps_SDS/new"
