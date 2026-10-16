#!/usr/bin/env bash
# Image pairing for every register step, with the new image CSV.
# Needs: run_steps_new_September.sh (or copy_register_results_new_September.sh) done first.
# Dataset: new_September   Results: /home/am/Documents/output_cohort/filtering_steps_SDS/new_September/with_images
# Run from anywhere:  bash run_image_steps_new_September.sh   (this script must be in the repo root, next to EHR_extract/)
# Existing results with the same names are OVERWRITTEN.
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"                      # repo root
export PYTHONPATH="$PWD"
export EHR_EXTRACT_CONFIGS="${EHR_EXTRACT_CONFIGS:-$PWD/configs}"
mkdir -p "/home/am/Documents/output_cohort/filtering_steps_SDS/new_September/with_images"

echo ">>> steps_SDS_img_0_base_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_0_base_new_September

echo ">>> steps_SDS_img_1_GA_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_1_GA_new_September

echo ">>> steps_SDS_img_2_live_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_2_live_new_September

echo ">>> steps_SDS_img_3_CS_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_3_CS_new_September

echo ">>> steps_SDS_img_4_induction_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_4_induction_new_September

echo ">>> steps_SDS_img_5_multiples_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_5_multiples_new_September

echo ">>> steps_SDS_img_6_parity_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_6_parity_new_September

echo "Done. Results in: /home/am/Documents/output_cohort/filtering_steps_SDS/new_September/with_images"
