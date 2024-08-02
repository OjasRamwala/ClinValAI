version 1.1
# version 1.1 required for gpu support

struct Input_Output_URIs
{
    String InputS3URI
    String OutputS3URI
}

workflow Mirai_agc_gpu 
{
    input
    {
        Array[Input_Output_URIs] URIs
    }

    scatter (URI in URIs)
    {
        call dataset_and_score
        {
            input: input_path=URI.InputS3URI, output_path=URI.OutputS3URI
        }
    }
}

task dataset_and_score
{
    input 
    {
        String input_path
        String output_path
    }
    command
    <<<
    echo "Present Working Directory"
    pwd
    original_path=$(pwd)
    cd
    pwd
    python3.6 record_workflowID.py ${original_path} ~{input_path} ~{output_path}
    cat /root/workflow_input_output.csv

    echo "Paths:"
    echo ~{input_path}
    echo ~{output_path}

    # echo "+++++ Test Code +++++"
    echo "+++++ Copy S3 Files ++++"
    python3.6 copy_S3files.py ~{input_path} # S3 URI --> D1_SABIR_YM_Batch4.zip
    ls
    cat /root/dataset_name.txt
    data=$(cat /root/dataset_name.txt) # D1_SABIR_YM_Batch4
    echo "+++++ Unzip ++++"
    unzip ${data}.zip -d /root/${data}

    echo "++++ Contents of the original dataset ++++"
    tree /root/${data}

    python3.6 data_restructure.py /root/${data}

    echo "++++ Contents of the restructured dataset ++++"
    tree /root/${data}

    python3.6 data_standardization.py /root/${data}

    echo "++++ Contents of the standardized dataset ++++"
    tree /root/${data}

    echo "++++ Initiating .dcm -> .png ++++"
    bash dcm_to_png.sh /root/${data}

    echo "++++ Contents after converting .dcm -> .png ++++"
    tree /root/${data} 

    echo "++++ Contents of the Metadata file ++++"
    cat /root/metadata.csv

    # change metadata file depending on the final set of images - check if image path (.png) exist - else remove entire exam
    python3.6 update_metadata.py /root/metadata.csv

    echo "++++ Contents of the Final Metadata file ++++"
    cat /root/metadata.csv

    cd /root/OncoNet
    python3.6 scripts/main.py  --model_name mirai_full \
    --img_encoder_snapshot snapshots/mgh_mammo_MIRAI_Base_May20_2019.p \
    --transformer_snapshot snapshots/mgh_mammo_cancer_MIRAI_Transformer_Jan13_2020.p \
    --callibrator_snapshot snapshots/callibrators/MIRAI_FULL_PRED_RF.callibrator.p --batch_size 1 \
    --dataset csv_mammo_risk_all_full_future --img_mean 7047.99 --img_size 1664 2048 --img_std 12005.5 \
    --metadata_path /root/metadata.csv --test --prediction_save_path /root/validation_output.csv \
    --num_workers 0 

    cd 
    echo "++++ Contents of the Validation Output ++++"
    cat /root/validation_output.csv

    python3.6 extract_scores.py /root/validation_output.csv ~{input_path} ~{output_path}
    echo "Task Job Completed!"
    

    # cd $original_path
    # mv /root/dataset_name.txt .
    # mv /root/${zipped_file}.zip "zipped_file.zip"
    # echo $(realpath ${zipped_file}.zip) > "dataset_name.txt"

    # ls

    # copy s3 files => download zip file 
    # unzip
    # data restructure 
    # data validation -> exactly 4 images/exam - all laterality and view combinations

    # .dcm -> .png # cd /root/OncoData

    # cd /root/OncoNet

    # create standard CSV file

    # Score

    # Output re-structuring -> CSV/year_risk

    # Upload to S3 URI

    >>>
    runtime
    {
        docker:"730335476018.dkr.ecr.us-west-2.amazonaws.com/risk-prediction/mirai:AIScoring"
        memory:"32G"
        gpu: true
        maxRetries: 1
    }
    output 
    {

    }
}



# version 1.1
# # version 1.1 required for gpu support

# struct Input_Output_URIs
# {
#     String InputS3URI
#     String OutputS3URI
# }

# workflow Mirai_agc_gpu 
# {
#     input
#     {
#         Array[Input_Output_URIs] URIs
#     }

#     scatter (URI in URIs)
#     {
#         call dataset_and_score
#         {
#             input: input_path=URI.InputS3URI, output_path=URI.OutputS3URI
#         }
#     }
# }

# task dataset_and_score
# {
#     input 
#     {
#         String input_path
#         String output_path
#     }
#     command
#     <<<
#     echo "Present Working Directory"
#     pwd
#     original_path=$(pwd)
#     cd
#     pwd
#     python3.6 record_workflowID.py ${original_path} ~{input_path} ~{output_path}
#     cat /root/workflow_input_output.csv

#     echo "Paths:"
#     echo ~{input_path}
#     echo ~{output_path}

#     # echo "+++++ Test Code +++++"
#     echo "+++++ Copy S3 Files ++++"
#     python3.6 copy_S3files.py ~{input_path} # S3 URI --> D1_SABIR_YM_Batch4.zip
#     ls
#     cat /root/dataset_name.txt
#     data=$(cat /root/dataset_name.txt) # D1_SABIR_YM_Batch4
#     echo "+++++ Unzip ++++"
#     unzip ${data}.zip -d /root/${data}

#     echo "++++ Contents of the original dataset ++++"
#     tree /root/${data}

#     python3.6 data_restructure.py /root/${data}

#     echo "++++ Contents of the restructured dataset ++++"
#     tree /root/${data}

#     python3.6 data_standardization.py /root/${data}

#     echo "++++ Contents of the standardized dataset ++++"
#     tree /root/${data}

#     echo "++++ Initiating .dcm -> .png ++++"
#     bash dcm_to_png.sh /root/${data}

#     echo "++++ Contents after converting .dcm -> .png ++++"
#     tree /root/${data} 

#     echo "++++ Contents of the Metadata file ++++"
#     cat /root/metadata.csv

#     # change metadata file depending on the final set of images - check if image path (.png) exist - else remove entire exam
#     python3.6 update_metadata.py /root/metadata.csv

#     echo "++++ Contents of the Final Metadata file ++++"
#     cat /root/metadata.csv

#     cd /root/OncoNet
#     python3.6 scripts/main.py  --model_name mirai_full \
#     --img_encoder_snapshot snapshots/mgh_mammo_MIRAI_Base_May20_2019.p \
#     --transformer_snapshot snapshots/mgh_mammo_cancer_MIRAI_Transformer_Jan13_2020.p \
#     --callibrator_snapshot snapshots/callibrators/MIRAI_FULL_PRED_RF.callibrator.p --batch_size 1 \
#     --dataset csv_mammo_risk_all_full_future --img_mean 7047.99 --img_size 1664 2048 --img_std 12005.5 \
#     --metadata_path /root/metadata.csv --test --prediction_save_path /root/validation_output.csv \
#     --num_workers 0 

#     cd 
#     echo "++++ Contents of the Validation Output ++++"
#     cat /root/validation_output.csv

#     python3.6 extract_scores.py /root/validation_output.csv ~{input_path} ~{output_path}
    

#     # cd $original_path
#     # mv /root/dataset_name.txt .
#     # mv /root/${zipped_file}.zip "zipped_file.zip"
#     # echo $(realpath ${zipped_file}.zip) > "dataset_name.txt"

#     # ls

#     # copy s3 files => download zip file 
#     # unzip
#     # data restructure 
#     # data validation -> exactly 4 images/exam - all laterality and view combinations

#     # .dcm -> .png # cd /root/OncoData

#     # cd /root/OncoNet

#     # create standard CSV file

#     # Score

#     # Output re-structuring -> CSV/year_risk

#     # Upload to S3 URI

#     >>>
#     runtime
#     {
#         docker:"730335476018.dkr.ecr.us-west-2.amazonaws.com/risk-prediction/mirai:AIScoring"
#         memory:"32G"
#         gpu: true
#         maxRetries: 1
#     }
#     output 
#     {

#     }
# }