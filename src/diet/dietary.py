import re
import sys
from pathlib import Path

import pandas as pd

project_root = Path(__file__).resolve().parents[2]
_src_dir = project_root / "src"
if str(_src_dir) not in sys.path:
    sys.path.insert(0, str(_src_dir))
from participant_id import normalize_participant_id_val

data_path = project_root / "data" / "raw" / "OPT_dietary data(ALL).csv"

PID_COL = "Participant ID (ESHA ID)"
# Valid participant anchor cells only (blocks note / junk text in the ID column)
_pid_cell = re.compile(
    r"^\s*OPT[_-]\d{1,2}(?:_T\d+)?\s*$",
    re.IGNORECASE,
)


def _pid_cell_valid(val) -> bool:
    if pd.isna(val):
        return False
    return bool(_pid_cell.match(str(val)))


def propagate_participant_ids(series: pd.Series) -> pd.Series:
    """
    Carry the last valid OPT anchor downward through blank ID cells.
    Non-matching non-empty cells (e.g. free-text notes) break the chain so they
    are not forward-filled from a previous participant.
    """
    out: list = []
    current = None
    for val in series:
        if pd.isna(val) or (isinstance(val, str) and not str(val).strip()):
            out.append(current)
            continue
        s = str(val).strip()
        if _pid_cell_valid(val):
            current = s
            out.append(s)
        else:
            current = None
            out.append(None)
    return pd.Series(out, index=series.index, dtype=object)


df = pd.read_csv(data_path, encoding="utf-8-sig")

# Remove rows with missing caloric intake
df = df[df["Cals (kcal)"].notna()]

# Remove summary rows (averages and % recommendation rows)
df = df[
    ~(
        (df["Day"] == "Average ")
        | (df["Day"].str.contains("% Recommendation", na=False))
    )
]

# Propagate only valid OPT-style anchors (excludes note rows from corrupting IDs)
df[PID_COL] = propagate_participant_ids(df[PID_COL])
df["Timepoint "] = df["Timepoint "].ffill()

# Drop visit suffix from participant IDs (e.g. OPT_02_T0 -> OPT_02); visit remains in Timepoint
df[PID_COL] = df[PID_COL].str.replace(r"_T\d+$", "", regex=True)

df[PID_COL] = df[PID_COL].map(normalize_participant_id_val)

# Keep only resolved OPT_NN codes (drops any remaining stray text)
df = df[
    df[PID_COL].astype(str).str.fullmatch(r"OPT_[0-9]{2}", case=False, na=False)
].copy()

# Select numerical columns starting from column index 3 onward
numerical_cols = df.iloc[:, 3:].select_dtypes(include=["number"]).columns

for col in numerical_cols:
    # Skip columns with no variation
    if df[col].nunique() <= 1:
        continue

    # Attempt quartile binning (q=4), fall back to median split (q=2) if needed
    for q in [4, 2]:
        try:
            df[f"{col}_quartile"] = pd.qcut(
                df[col], q=q, labels=False, duplicates="drop"
            )
            break
        except ValueError:
            continue


output_path = project_root / "data" / "processed" / "dietary_cleaned.xlsx"

quartile_cols = [col for col in df.columns if col.endswith("_quartile")]
main_cols = [col for col in df.columns if not col.endswith("_quartile")]

with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
    df[main_cols].to_excel(writer, sheet_name="Data", index=False)
    df[main_cols[:2] + quartile_cols].to_excel(
        writer, sheet_name="Quartiles", index=False
    )
