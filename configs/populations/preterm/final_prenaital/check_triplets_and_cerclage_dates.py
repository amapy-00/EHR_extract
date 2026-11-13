"""
Answers two questions on YOUR registers before running the new population:

  A. TRIPLETS - which sources show them, and do they agree?
       births with >= 3 children registered (nyfoedte: DW_EK_Foedsel + mother, mfr: FOEDSELSLOEBENUMMER + mother)
       births with a triplet+ code (DO301 DO302 DO308 DZ375 DZ376 DZ377) in mor_diagnoser / t_diag
     + any column whose name suggests plurality (number of fetuses, twin/triplet flag, fetus number)

  B. CERCLAGE DATES - which cerclage sources carry a date?
       lists the date-like columns of mor_procedurer, mor_diagnoser, t_sksopr, t_diag
       and counts cerclage records (codes below) per source

Memory-light (lazy reading, only the needed columns). Run:  python check_triplets_and_cerclage_dates.py
"""
import os

import polars as pl

# ============================== SETTINGS ==============================
SDS_DIR = "/home/am/data/raw/sds"
TRIPLET_CODES = ["DO301", "DO302", "DO308", "DZ375", "DZ376", "DZ377"]
CERCLAGE_DIAGNOSES = ["DO343C"]
CERCLAGE_PROCEDURES = ["KLDD10A", "KLDD10B", "KMAB00", "KMAB01", "KLDD20", "KMAB03"]
# ======================================================================

DATE_HINTS = ("dato", "dto", "date", "dt_", "_dt", "tid", "time")
PLURALITY_HINTS = ("flerfold", "antal", "foster", "plural", "tvilling", "trilling", "multiple", "fodselsnr", "foedselsnr", "nummer")


def scan(name):
    path = os.path.join(SDS_DIR, name)
    return pl.scan_csv(path, infer_schema=False) if os.path.isfile(path) else None


def cols(lf):
    return lf.collect_schema().names()


print("=" * 90 + "\nColumns that may matter\n" + "=" * 90)
for name in ["mfr.csv", "nyfoedte.csv", "mor_diagnoser.csv", "mor_procedurer.csv", "t_diag.csv", "t_sksopr.csv"]:
    lf = scan(name)
    if lf is None:
        print(f"{name:<20} NOT FOUND in {SDS_DIR}")
        continue
    c = cols(lf)
    dates = [x for x in c if any(h in x.lower() for h in DATE_HINTS)]
    plural = [x for x in c if any(h in x.lower() for h in PLURALITY_HINTS) and "cpr" not in x.lower()]
    print(f"{name:<20} {len(c)} columns")
    print(f"{'':<20} date-like:      {dates or '(none)'}")
    print(f"{'':<20} plurality-like: {plural or '(none)'}")

# ------------------------------------------------------------------ A. triplets
print("\n" + "=" * 90 + "\nA. TRIPLETS (births with 3 or more babies)\n" + "=" * 90)
found = {}
ny, mfr = scan("nyfoedte.csv"), scan("mfr.csv")
if ny is not None:
    g = (ny.filter(pl.col("DW_EK_Foedsel").is_not_null())
           .group_by(["DW_EK_Foedsel", "CPRnummer_Mor"]).agg(pl.col("CPRnummer_Barn").n_unique().alias("n"))
           .collect(engine="streaming"))
    print("nyfoedte: children per birth:", dict(sorted(g["n"].value_counts().iter_rows())))
    found["nyfoedte count >= 3"] = set(g.filter(pl.col("n") >= 3)["CPRnummer_Mor"])
if mfr is not None:
    g = (mfr.filter(pl.col("FOEDSELSLOEBENUMMER").is_not_null())
            .group_by(["FOEDSELSLOEBENUMMER", "CPR_MODER"]).agg(pl.col("CPR_BARN").n_unique().alias("n"))
            .collect(engine="streaming"))
    print("mfr:      children per birth:", dict(sorted(g["n"].value_counts().iter_rows())))
    found["mfr count >= 3"] = set(g.filter(pl.col("n") >= 3)["CPR_MODER"])
md = scan("mor_diagnoser.csv")
if md is not None and ny is not None:
    births = md.filter(pl.col("DiagnoseKode").is_in(TRIPLET_CODES)).select("DW_EK_Foedsel").unique()
    moms = births.join(ny.select("DW_EK_Foedsel", "CPRnummer_Mor"), on="DW_EK_Foedsel").collect(engine="streaming")
    found["mor_diagnoser code"] = set(moms["CPRnummer_Mor"])
td, adm = scan("t_diag.csv"), scan("t_adm.csv")
if td is not None and adm is not None:
    recs = td.filter(pl.col("C_DIAG").is_in(TRIPLET_CODES) | pl.col("C_TILDIAG").is_in(TRIPLET_CODES)).select("V_RECNUM").unique()
    moms = recs.join(adm.select("K_RECNUM", "V_CPR"), left_on="V_RECNUM", right_on="K_RECNUM").collect(engine="streaming")
    found["t_diag code (any date)"] = set(moms["V_CPR"])
for k, v in found.items():
    print(f"  mothers flagged by {k:<26} {len(v):>7,}")
if len(found) > 1:
    union = set().union(*found.values())
    print(f"  mothers flagged by ANY source           {len(union):>7,}")
    for k, v in found.items():
        print(f"    of those, also flagged by {k:<26} {len(v & union):>7,}   only by this source: {len(v - set().union(*(w for j, w in found.items() if j != k))):,}")
print("  (counted per mother, all years; t_diag is not restricted to a pregnancy here)")

# ------------------------------------------------------------------ B. cerclage dates
print("\n" + "=" * 90 + "\nB. CERCLAGE records per source, and whether they have a date\n" + "=" * 90)
for name, column, codes in [("mor_diagnoser.csv", "DiagnoseKode", CERCLAGE_DIAGNOSES), ("t_diag.csv", "C_DIAG", CERCLAGE_DIAGNOSES),
                            ("mor_procedurer.csv", "ProcedureKode", CERCLAGE_PROCEDURES), ("t_sksopr.csv", "C_OPR", CERCLAGE_PROCEDURES)]:
    lf = scan(name)
    if lf is None or column not in cols(lf):
        print(f"{name:<20} {column}: not available")
        continue
    dates = [x for x in cols(lf) if any(h in x.lower() for h in DATE_HINTS)]
    sel = lf.filter(pl.col(column).is_in(codes))
    n = sel.select(pl.len()).collect(engine="streaming").item()
    line = f"{name:<20} {column:<14} cerclage records: {n:>7,}   date columns: {dates or 'NONE'}"
    if dates and n:
        filled = sel.select([pl.col(d).is_not_null().sum().alias(d) for d in dates]).collect(engine="streaming").row(0, named=True)
        line += "   filled: " + ", ".join(f"{d} {v:,}" for d, v in filled.items())
    print(line)
