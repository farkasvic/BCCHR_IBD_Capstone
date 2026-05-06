import os

import pandas as pd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
data_dir = os.path.join(ROOT_DIR, "data")
processed_dir = os.path.join(data_dir, "processed")

os.makedirs(processed_dir, exist_ok=True)

META_COLS = {
    "Sample_ID",
    "Participant_ID",
    "Sample_type",
    "Study_group_new",
    "Fiber_restriction",
}

# MBI SS_ID visit codes (last letter) → dietary Timepoint labels
SS_ID_SUFFIX_TO_TIMEPOINT = {"Z": "T0", "Q": "T1", "T": "T2"}


def _load_characteristics(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    df["participant_id"] = df["participant_id"].astype(str).str.upper().str.strip()
    return df


def merge_genus_species(genus: pd.DataFrame, species: pd.DataFrame) -> pd.DataFrame:
    """Inner join genus and species microbiome matrices on Sample_ID."""
    genus = genus.copy()
    species_only = species[[c for c in species.columns if c not in META_COLS or c == "Sample_ID"]].copy()
    if "NA" in genus.columns and "NA" in species_only.columns:
        species_only = species_only.rename(columns={"NA": "NA_species"})
    merged = genus.merge(species_only, on="Sample_ID", how="inner")
    merged["Participant_ID"] = merged["Participant_ID"].astype(str).str.upper().str.strip()
    return merged


def merge_characteristics_genus_species(chars: pd.DataFrame, genus_species: pd.DataFrame) -> pd.DataFrame:
    """Inner join cleaned characteristics with processed genus/species."""
    gs = genus_species.copy()
    merged = chars.merge(gs, left_on="participant_id", right_on="Participant_ID", how="inner")
    if "participant_id" in merged.columns and "Participant_ID" in merged.columns:
        merged = merged.drop(columns=["Participant_ID"])
    return merged


def merge_characteristics_dietary(chars: pd.DataFrame, dietary: pd.DataFrame) -> pd.DataFrame:
    """Inner join characteristics with cleaned dietary (participant_id + aligned timepoints)."""
    d = dietary.copy()
    pid_col = "Participant ID (ESHA ID)"
    tp_col = "Timepoint "

    chars = chars.copy()
    chars["_merge_tp"] = chars["event_name"].astype(str).str.extract(r"(T\d+)", expand=False)

    d["_pid_norm"] = d[pid_col].astype(str).str.upper().str.strip()
    d["_tp_norm"] = d[tp_col].astype(str).str.strip()

    merged = chars.merge(d, left_on=["participant_id", "_merge_tp"], right_on=["_pid_norm", "_tp_norm"], how="inner")

    merged = merged.drop(columns=["_merge_tp", "_pid_norm", "_tp_norm"], errors="ignore")
    return merged


def load_dietary_cleaned(path_csv: str, path_xlsx: str) -> pd.DataFrame:
    if os.path.isfile(path_csv):
        return pd.read_csv(path_csv)
    if os.path.isfile(path_xlsx):
        return pd.read_excel(path_xlsx, sheet_name="Data", engine="openpyxl")
    raise FileNotFoundError(
        f"Cleaned dietary data not found at {path_csv} or {path_xlsx}. Run dietary.py first."
    )


def load_mbi_metadata(path: str) -> pd.DataFrame:
    m = pd.read_csv(path)
    m["Sample_ID"] = m["Sample_ID"].astype(str).str.strip()
    m["Participant_ID"] = m["Participant ID"].astype(str).str.upper().str.strip()
    return m


def timepoint_from_ss_id(ss_id: pd.Series) -> pd.Series:
    """Infer T0/T1/T2 from MBI SS_ID visit suffix (e.g. 7Z → T0, 7Q → T1, 7T → T2)."""
    suffix = ss_id.astype(str).str.extract(r"([ZQT])$", expand=False)
    return suffix.str.upper().map(SS_ID_SUFFIX_TO_TIMEPOINT)


def merge_dietary_genus_species_via_mbi(
    genus_species: pd.DataFrame,
    dietary: pd.DataFrame,
    mbi: pd.DataFrame,
) -> pd.DataFrame:
    """
    Inner join dietary + genus + species using MBI metadata: Sample_ID links stool to visit;
    SS_ID suffix maps to dietary Timepoint; Participant_ID links to dietary participant IDs.
    """
    bridge = mbi[["Sample_ID", "SS_ID"]].copy()
    bridge["_tp"] = timepoint_from_ss_id(bridge["SS_ID"])
    bridge = bridge.dropna(subset=["_tp"])

    gs = genus_species.merge(bridge, on="Sample_ID", how="inner")

    d = dietary.copy()
    pid_col = "Participant ID (ESHA ID)"
    tp_col = "Timepoint "
    d["_pid"] = d[pid_col].astype(str).str.upper().str.strip()
    d["_tp"] = d[tp_col].astype(str).str.strip()

    merged = gs.merge(
        d,
        left_on=["Participant_ID", "_tp"],
        right_on=["_pid", "_tp"],
        how="inner",
    )
    drop_cols = [c for c in ("_pid", "_tp") if c in merged.columns]
    merged = merged.drop(columns=drop_cols)
    return merged


characteristics_path = os.path.join(processed_dir, "cleaned_characteristics.csv")
genus_path = os.path.join(processed_dir, "genus.csv")
species_path = os.path.join(processed_dir, "species.csv")
dietary_csv = os.path.join(processed_dir, "dietary_cleaned.csv")
dietary_xlsx = os.path.join(processed_dir, "dietary_cleaned.xlsx")
mbi_path = os.path.join(data_dir, "OPT_MBI sample IDs meta.csv")
mbi_path_alt = os.path.join(data_dir, "raw", "OPT_MBI sample IDs meta(Sheet1).csv")

for path, label in [
    (characteristics_path, "cleaned_characteristics.csv"),
    (genus_path, "genus.csv"),
    (species_path, "species.csv"),
]:
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Missing {label} at {path}")

if not os.path.isfile(mbi_path):
    if os.path.isfile(mbi_path_alt):
        mbi_path = mbi_path_alt
    else:
        raise FileNotFoundError(
            f"MBI sample metadata not found at {mbi_path} or {mbi_path_alt}"
        )

characteristics = _load_characteristics(characteristics_path)
genus = pd.read_csv(genus_path)
species = pd.read_csv(species_path)
dietary = load_dietary_cleaned(dietary_csv, dietary_xlsx)
mbi = load_mbi_metadata(mbi_path)

genus_species = merge_genus_species(genus, species)

out1 = merge_characteristics_genus_species(characteristics, genus_species)
out1_path = os.path.join(processed_dir, "characteristics_genus_species_inner.csv")
out1.to_csv(out1_path, index=False)
print(f"Saved (characteristics + genus + species, inner): {out1_path} — {len(out1)} rows")

out2 = merge_characteristics_dietary(characteristics, dietary)
out2_path = os.path.join(processed_dir, "characteristics_dietary_inner.csv")
out2.to_csv(out2_path, index=False)
print(f"Saved (characteristics + dietary, inner): {out2_path} — {len(out2)} rows")

out3 = merge_characteristics_dietary(out1, dietary)
out3_path = os.path.join(processed_dir, "characteristics_genus_species_dietary_inner.csv")
out3.to_csv(out3_path, index=False)
print(f"Saved (all sources, inner): {out3_path} — {len(out3)} rows")

out4 = merge_dietary_genus_species_via_mbi(genus_species, dietary, mbi)
out4_path = os.path.join(processed_dir, "dietary_genus_species_mbi_inner.csv")
out4.to_csv(out4_path, index=False)
print(f"Saved (dietary + genus + species via MBI, inner): {out4_path} — {len(out4)} rows")
