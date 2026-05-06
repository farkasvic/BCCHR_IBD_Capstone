import pandas as pd
import numpy as np

from pathlib import Path

data_path = Path(__file__).parent.parent / 'data' / 'OPT_dietary data(ALL).csv'
df = pd.read_csv(data_path, encoding='cp1252')

# Remove rows with missing caloric intake
df = df[df['Cals (kcal)'].notna()]

# Remove summary rows (averages and % recommendation rows)
df = df[~(
    (df['Day'] == 'Average ') |
    (df['Day'].str.contains('% Recommendation', na=False))
)]

#  Forward-fill identifiers
# Participant ID and Timepoint are only listed once per block; propagate downward
df['Participant ID (ESHA ID)'] = df['Participant ID (ESHA ID)'].ffill()
df['Timepoint '] = df['Timepoint '].ffill()

# Drop visit suffix from participant IDs (e.g. OPT_02_T0 -> OPT_02); visit remains in Timepoint
df["Participant ID (ESHA ID)"] = df["Participant ID (ESHA ID)"].str.replace(
    r"_T\d+$", "", regex=True
)

# Select numerical columns starting from column index 3 onward
numerical_cols = df.iloc[:, 3:].select_dtypes(include=['number']).columns

for col in numerical_cols:
    # Skip columns with no variation
    if df[col].nunique() <= 1:
        continue

    # Attempt quartile binning (q=4), fall back to median split (q=2) if needed
    for q in [4, 2]:
        try:
            df[f'{col}_quartile'] = pd.qcut(df[col], q=q, labels=False, duplicates='drop')
            break
        except ValueError:
            continue  


# output_path = Path(__file__).parent.parent / 'data' / 'processed' / 'dietary_cleaned.csv'
# df.to_csv(output_path, index=False)

output_path = Path(__file__).parent.parent / 'data' / 'processed' / 'dietary_cleaned.xlsx'

quartile_cols = [col for col in df.columns if col.endswith('_quartile')]
main_cols = [col for col in df.columns if not col.endswith('_quartile')]

with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
    df[main_cols].to_excel(writer, sheet_name='Data', index=False)
    df[main_cols[:2] + quartile_cols].to_excel(writer, sheet_name='Quartiles', index=False)