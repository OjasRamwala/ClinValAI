#!/bin/bash -e
dataset="$1"
for folder in "$dataset"/*; do
    if [ -d "$folder" ]; then
        echo "Processing Exam: $folder"
        python3.6 /root/OncoData/scripts/dicom_to_png/dicom_to_png.py --dcmtk --dicom_dir "$folder" --png_dir "$folder"
    fi
done