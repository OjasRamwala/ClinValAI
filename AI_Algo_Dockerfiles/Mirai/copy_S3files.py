# Working code
import boto3
import sys
import os
print("New Docker Image!!")
session = boto3.Session()
s3 = session.client('s3')
# s3.download_file('bcsc-external-validation', 'UC_Davis/Batch D/D1_SABIR_YM_Batch4.zip', 'D1_SABIR_YM_Batch4.zip')

s = str(sys.argv[1])
l = s.split("/") # ['s3:', '', 'bcsc-external-validation', 'UC_Davis', 'Batch_D', 'D1_SABIR_YM_Batch4.zip']
s3.download_file(str(l[2]), '/'.join(l[3:]), str(l[-1])) 


with open('dataset_name.txt', 'w') as f:
    f.write(l[-1][:-4]) # D1_SABIR_YM_Batch4

# import os
# import sys
# import boto3
# s3=boto3.client('s3')

# # s3://imds-external-validation/UW/Set_1/NWSCORE25TestAnon/


# # s3_key: imds-external-validation/UW/Set_1/NWSCORE25TestAnon/70000000001/MAM_MAMMOGRAPHY_SCREENING/1.2.840.113654.2.70.1.122990220592507877760938290819713664641
# def download_file(bucket_name, s3_key, local_path):
#     if not os.path.exists(os.path.dirname(local_path)):
#         os.makedirs(os.path.dirname(local_path))
#     s3.download_file(bucket_name, s3_key, local_path)

# def download_from_s3(s3_uri, local_dir):
#     if not s3_uri.startswith("s3://"):
#         raise ValueError("Invalid S3 URI")
    
#     s3_uri_parts=s3_uri[5:].split('/') # remove "s3://" 
#     bucket_name=s3_uri_parts[0] # imds-external-validation
#     prefix='/'.join(s3_uri_parts[1:]) # UW/Set_1/NWSCORE25TestAnon/

#     paginator=s3.get_paginator('list_objects_v2')
#     pages=paginator.paginate(Bucket=bucket_name, Prefix=prefix)

#     for page in pages:
#         if 'Contents' in page:
#             for obj in page['Contents']:
#                 s3_key=obj['Key']
#                 local_file_path=os.path.join(local_dir, os.path.relpath(s3_key, prefix))
#                 download_file(bucket_name, s3_key, local_file_path)

    

# s3_uri = str(sys.argv[1])
# l = s3_uri.split("/")
# local_directory=l[-2]
# with open('dataset_name.txt', 'w') as f:
#     f.write(local_directory) # NWSCORE25TestAnon