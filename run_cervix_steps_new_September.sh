#!/usr/bin/env bash
# Cervix filter on the image CSVs of every step.
# Needs: run_image_steps_new_September.sh done first.
# Dataset: new_September   Results: /home/am/Documents/output_cohort/filtering_steps_SDS/new_September/with_images/with_cervix
# Run from anywhere:  bash run_cervix_steps_new_September.sh   (this script must be in the repo root, next to EHR_extract/)
# Existing results with the same names are OVERWRITTEN.
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"                      # repo root
export PYTHONPATH="$PWD"
export EHR_EXTRACT_CONFIGS="${EHR_EXTRACT_CONFIGS:-$PWD/configs}"
mkdir -p "/home/am/Documents/output_cohort/filtering_steps_SDS/new_September/with_images/with_cervix"

echo ">>> steps_SDS_img_cervix_0_base_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_cervix_0_base_new_September

echo ">>> steps_SDS_img_cervix_1_GA_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_cervix_1_GA_new_September

echo ">>> steps_SDS_img_cervix_2_live_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_cervix_2_live_new_September

echo ">>> steps_SDS_img_cervix_3_CS_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_cervix_3_CS_new_September

echo ">>> steps_SDS_img_cervix_4_induction_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_cervix_4_induction_new_September

echo ">>> steps_SDS_img_cervix_5_multiples_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_cervix_5_multiples_new_September

echo ">>> steps_SDS_img_cervix_6_cerclage_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_cervix_6_cerclage_new_September

echo ">>> steps_SDS_img_cervix_7_progesterone_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_cervix_7_progesterone_new_September

echo ">>> steps_SDS_img_cervix_8_parity_new_September"
python EHR_extract/extract.py --config-name steps_SDS_img_cervix_8_parity_new_September

echo "Done. Results in: /home/am/Documents/output_cohort/filtering_steps_SDS/new_September/with_images/with_cervix"
