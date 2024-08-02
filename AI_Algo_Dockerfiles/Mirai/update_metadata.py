import os
import sys
import pandas as pd
import shutil

df=pd.read_csv(sys.argv[1])
print("Metadata:", df)

drop_rows=[]
for patient, patient_df in df.groupby('patient_id'):
    flag=0
    for index, img_path in (patient_df['file_path'].items()):
        if (not os.path.exists(img_path)):
            flag=1
        if (flag==1):
            drop_rows.append(index)
metadata=df.drop(drop_rows)
metadata.to_csv(sys.argv[1], index=False)