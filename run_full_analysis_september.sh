#!/usr/bin/env bash
# =====================================================================================
# run_full_analysis.sh - re-run the whole image analysis with a new image database CSV
#
#   1 check      the new image CSV has the columns the image configs need, dates are YYYYMMDD,
#                and how many of its images have a cervix prediction
#   2 register   (optional, RERUN_REGISTER=1) register steps steps_SDS_0_base ... steps_SDS_6_parity.
#                Not needed for a new IMAGE database: the registers did not change.
#   3 images     steps_SDS_img_<k> for every step, with the NEW image CSV
#   4 cervix     steps_SDS_img_cervix_<k> for every step
#   5 summaries  step_summary, image_step_summary (all + cervix), hospital_summary,
#                institution_summary, flowchart, region_loss_analysis
#
# Nothing in the YAML configs has to be edited: the new paths are passed as Hydra overrides, and
# every result of this run goes to its own folder (RUN_DIR), so the previous results are kept.
#
# Usage (from the repo root, where EHR_extract/extract.py is; the summary scripts can be in SCRIPTS_DIR):
#   bash run_full_analysis.sh                     # everything, with the settings below - no arguments needed
#   STAGES="summaries" bash run_full_analysis.sh  # only some stages (check register images cervix summaries)
#   FORCE=1 bash run_full_analysis.sh             # recompute configs whose output already exists
# =====================================================================================

# ============================== SETTINGS - edit these ==============================
# Defaults = the files you use now, so `bash run_full_analysis.sh` works with no arguments.
# For a new database, change NEW_IMAGES (and CERVIX_PREDS if the predictions were remade).
NEW_IMAGES="/home/am/Documents/DeepFetalCSVs/new_September/DeepFetal_image_database_090926_joined_on_sop_instance_uid_and_xx-file_hash.csv"
CERVIX_PREDS="/home/am/data/raw/research_common/cervix_preds_v3.csv"         # cervix predictions (file_path, is_cervix)
SCRIPTS_DIR="/home/am/Documents/output_cohort/filtering_steps_SDS"           # where the summary .py scripts are
MAPPING="/home/am/Documents/output_cohort/filtering_steps_SDS/institution_mapping.yaml"           # file name or full path; looked for in the repo root, then in SCRIPTS_DIR
SDS_DIR="/home/am/data/raw/sds"                                              # mfr.csv, nyfoedte.csv, ...
# Where the results are. Defaults = your existing folders, so existing results are found and reused
# (configs whose output CSV is already there are skipped; FORCE=1 recomputes and OVERWRITES them).
STEPS_DIR="/home/am/Documents/output_cohort/filtering_steps_SDS/new_September"             # register steps: steps_SDS_<k>_..._train_and_test.csv
RUN_DIR="/home/am/Documents/output_cohort/filtering_steps_SDS/new_September"               # base folder of the image results
IMG_DIR="$RUN_DIR/with_images"                                               # steps_SDS_img_<k>_..._train_and_test.csv
CX_DIR="$RUN_DIR/with_images/with_cervix"                                    # steps_SDS_img_cervix_<k>_..._train_and_test.csv
SUM_DIR="$RUN_DIR/summaries"                                                 # all summary tables and figures
# For a NEW database, use a new folder so the current results are kept, e.g.:
#   RUN_DIR="/home/am/Documents/output_cohort/run_$(date +%Y-%m-%d)"
#   IMG_DIR="$RUN_DIR/with_images";  CX_DIR="$RUN_DIR/with_images/with_cervix";  SUM_DIR="$RUN_DIR/summaries"

RERUN_REGISTER=1                     # 1 = also recompute the register steps (only if the registers changed)
STEPS="0_base 1_GA 2_live 3_CS 4_induction 5_multiples 6_parity"
FINAL_STEP="5_multiples"             # step used for the hospital / flowchart / region analyses
SCAN_LOW=111; SCAN_HIGH=224          # GA at scan window, strict: 111 < GA < 224  = 16+0 to 31+6 weeks
POS_MIN=112;  POS_MAX=223            # positive = GA at birth 16+0 to 31+6 weeks (flowchart)
GA_BIRTH_MAX=224                     # region analysis: GA at birth <= 32+0 weeks
# ====================================================================================

STAGES="${STAGES:-check register images cervix summaries}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"
export PYTHONPATH="$REPO_ROOT${PYTHONPATH:+:$PYTHONPATH}"
export EHR_EXTRACT_CONFIGS="${EHR_EXTRACT_CONFIGS:-$REPO_ROOT/configs}"
export EHR_EXTRACT_OUTPUTS="$STEPS_DIR"     # the image configs read the register-step CSVs from here

mkdir -p "$IMG_DIR" "$CX_DIR" "$SUM_DIR" "$RUN_DIR/logs"
# mapping: as given, else in SCRIPTS_DIR
if [[ ! -f "$MAPPING" && -f "$SCRIPTS_DIR/$MAPPING" ]]; then MAPPING="$SCRIPTS_DIR/$MAPPING"; fi
LOG="$RUN_DIR/logs/run_$(date +%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
FAILED=()

banner() { echo; echo "=================== $* ==================="; }
want()   { [[ " $STAGES " == *" $1 "* ]]; }
done_already() { [[ -f "$1_population_train_and_test.csv" && -z "$FORCE" ]]; }

run_config() {   # run_config <config name> <output folder> [extra overrides...]
  local cfg="$1" out="$2"; shift 2
  if done_already "$out/$cfg"; then echo ">>> $cfg: output exists, skipping (FORCE=1 to re-run)"; return 0; fi
  echo ">>> running $cfg"
  if ! python EHR_extract/extract.py --config-name "$cfg" \
        "paths.output_dir=$out/$cfg" \
        "paths.population_save_path=$out/${cfg}_population" \
        "paths.discards_save_path=$out/${cfg}_discards" "$@"; then
    echo "!!! $cfg FAILED - stopping (later steps depend on it)"; exit 1
  fi
}

run_py() {       # run_py <name> <command...>   (a failing summary does not stop the others)
  local name="$1"; shift
  echo ">>> $name"
  if ! "$@"; then echo "!!! $name FAILED (see above)"; FAILED+=("$name"); fi
}

echo "Run started $(date)"
echo "  new image CSV : $NEW_IMAGES"
echo "  register steps: $STEPS_DIR"
echo "  image CSVs    : $IMG_DIR"
echo "  cervix CSVs   : $CX_DIR"
echo "  summaries     : $SUM_DIR"
echo "  scripts       : $SCRIPTS_DIR"
echo "  log           : $LOG"

# ------------------------------------------------------------------ 1 check
if want check; then
  banner "1 CHECK the new image CSV"
  [[ -f "$NEW_IMAGES" ]] || { echo "Not found: $NEW_IMAGES"; exit 1; }
  [[ -f "$MAPPING" ]] || { echo "Not found: $MAPPING (put institution_mapping.yaml in the repo root or in SCRIPTS_DIR, or set MAPPING)"; exit 1; }
  echo "  mapping: $MAPPING"
  for s in step_summary.py image_step_summary.py hospital_summary.py institution_summary.py flowchart.py region_loss_analysis.py; do
    [[ -f "$SCRIPTS_DIR/$s" ]] || echo "  WARNING: $s not found in $SCRIPTS_DIR - that summary will fail"
  done
  python - "$NEW_IMAGES" "$CERVIX_PREDS" <<'PY' || exit 1
import sys, os, polars as pl
path, preds = sys.argv[1], sys.argv[2]
need = ["file_hash", "file_path", "study_date", "physical_delta_x", "physical_delta_y",
        "no_ocr_preprocessed_file_path", "institution_name"]          # names used in the image configs
cols = pl.scan_csv(path, infer_schema=False).collect_schema().names()
missing = [c for c in need if c not in cols]
print(f"  columns: {cols}")
if missing:
    sys.exit(f"  MISSING columns {missing}: rename them in the CSV, or change imaging_table.columns "
             "in the steps_SDS_img_* configs")
if "phair_hash" in cols:
    print("  NOTE: this CSV has a 'phair_hash' column. The image configs use file_hash as the mother ID "
          "(CPR_MOR: file_hash) - check which one is the mother's pseudonymised CPR.")
head = pl.scan_csv(path, infer_schema=False).select("study_date").head(2000).collect()["study_date"].drop_nulls()
bad = head.filter(~head.str.contains(r"^\d{8}$"))
print(f"  study_date examples: {head.head(3).to_list()}")
if bad.len():
    sys.exit(f"  study_date must be YYYYMMDD (the pipeline parses it with %Y%m%d); found e.g. {bad.head(3).to_list()}")
h = lambda c: pl.col(c).cast(pl.String).hash(seed=0)
n = pl.scan_csv(path, infer_schema=False).select(h("file_path").alias("p")).unique().select(pl.len()).collect(engine="streaming").item()
print(f"  distinct images: {n:,}")
if os.path.isfile(preds):
    pp = pl.scan_csv(preds, infer_schema=False).select(h("file_path").alias("p")).unique().collect(engine="streaming")["p"]
    k = (pl.scan_csv(path, infer_schema=False).select(h("file_path").alias("p")).unique()
           .filter(pl.col("p").is_in(pp.implode())).select(pl.len()).collect(engine="streaming").item())
    print(f"  images with a cervix prediction: {k:,} of {n:,} ({100 * k / max(n, 1):.1f}%)")
    if k < 0.9 * n:
        print("  WARNING: many images have NO cervix prediction. They will never count as cervix images. "
              "Run the cervix classifier on the new database first, or point CERVIX_PREDS to the new file.")
else:
    print(f"  WARNING: cervix prediction file not found: {preds}")
PY
fi

# ------------------------------------------------------------------ 2 register (optional)
if want register && [[ "$RERUN_REGISTER" == "1" ]]; then
  banner "2 REGISTER steps -> $STEPS_DIR"
  for k in $STEPS; do run_config "steps_SDS_$k" "$STEPS_DIR" "paths.input_dir_SDS=$SDS_DIR"; done
elif want register; then
  banner "2 REGISTER steps: skipped (RERUN_REGISTER=0), reusing $STEPS_DIR"
fi

# ------------------------------------------------------------------ 3 image pairing
if want images; then
  banner "3 IMAGE PAIRING -> $IMG_DIR"
  for k in $STEPS; do
    [[ -f "$STEPS_DIR/steps_SDS_${k}_population_train_and_test.csv" ]] || {
      echo "Missing register step: $STEPS_DIR/steps_SDS_${k}_population_train_and_test.csv"; exit 1; }
    run_config "steps_SDS_img_$k" "$IMG_DIR" "paths.imaging_table=$NEW_IMAGES"
  done
fi

# ------------------------------------------------------------------ 4 cervix
if want cervix; then
  banner "4 CERVIX FILTER -> $CX_DIR"
  for k in $STEPS; do
    run_config "steps_SDS_img_cervix_$k" "$CX_DIR" "img_csv_dir=$IMG_DIR" "paths.img_sequence_predictions=$CERVIX_PREDS"
  done
fi

# ------------------------------------------------------------------ 5 summaries
if want summaries; then
  banner "5 SUMMARIES -> $SUM_DIR"
  run_py "step_summary (register steps)" \
    python "$SCRIPTS_DIR/step_summary.py" --outputs "$STEPS_DIR" --ga-below 224 259 --csv "$SUM_DIR/step_summary.csv"
  run_py "image_step_summary (all images; also adds GA_at_scan to the image CSVs)" \
    python "$SCRIPTS_DIR/image_step_summary.py" --outputs "$STEPS_DIR" --img-outputs "$IMG_DIR" \
      --window "$SCAN_LOW" "$SCAN_HIGH" --window 112 168 --csv "$SUM_DIR/image_step_summary_all.csv"
  run_py "image_step_summary (cervix images)" \
    python "$SCRIPTS_DIR/image_step_summary.py" --outputs "$STEPS_DIR" --img-outputs "$CX_DIR" --img-prefix steps_SDS_img_cervix_ \
      --window "$SCAN_LOW" "$SCAN_HIGH" --window 112 168 --csv "$SUM_DIR/image_step_summary_cervix.csv"
  run_py "hospital_summary" \
    python "$SCRIPTS_DIR/hospital_summary.py" --img-dir "$IMG_DIR" --cervix-dir "$CX_DIR" --mapping "$MAPPING" \
      --step "$FINAL_STEP" --out-dir "$SUM_DIR/hospital_summary"
  run_py "institution_summary" \
    python "$SCRIPTS_DIR/institution_summary.py" --img-dir "$CX_DIR" --mapping "$MAPPING" \
      --final-step "$FINAL_STEP" --out-dir "$SUM_DIR/institution_summary"
  run_py "flowchart" \
    python "$SCRIPTS_DIR/flowchart.py" --steps-dir "$STEPS_DIR" --img-dir "$IMG_DIR" --cervix-dir "$CX_DIR" \
      --final-step "$FINAL_STEP" --window "$SCAN_LOW" "$SCAN_HIGH" \
      --positive-min-days "$POS_MIN" --positive-max-days "$POS_MAX" --out-dir "$SUM_DIR/flowchart"
  run_py "region_loss_analysis" \
    python "$SCRIPTS_DIR/region_loss_analysis.py" --raw-images "$NEW_IMAGES" --sds-dir "$SDS_DIR" \
      --img-dir "$IMG_DIR" --cervix-dir "$CX_DIR" --mapping "$MAPPING" \
      --last-step "$FINAL_STEP" --max-ga-birth "$GA_BIRTH_MAX" --window "$SCAN_LOW" "$SCAN_HIGH" \
      --out-dir "$SUM_DIR/region_loss"
fi

banner "DONE $(date)"
echo "Results: $RUN_DIR"
if ((${#FAILED[@]})); then echo "Summaries that FAILED: ${FAILED[*]}"; exit 1; fi