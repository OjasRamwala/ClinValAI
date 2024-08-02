import os
import stat
import boto3
import json
import subprocess
input_path = "s3://imds-standardized-inputs/UW/UW_Dataset"
output_path = "s3://imds-scores/UW/Mirai/UW_Dataset" 
input_l = input_path.split('/')

session = boto3.Session()
s3 = session.resource('s3')
bucket = s3.Bucket(input_l[2])
count = 0
input_output_uri=[]
for obj in bucket.objects.all():
    if (str(obj.key).startswith(str(input_l[3] + "/" + input_l[4])) and str(obj.key).endswith('.zip')):
        count+=1
        input_output_d = {}
        input_output_d["InputS3URI"] = str(input_l[0] + '/' + input_l[1] + '/' + input_l[2] + '/' + obj.key)
        input_output_d["OutputS3URI"] = output_path
        input_output_uri.append(input_output_d)
d={}
d["Mirai_agc_gpu.URIs"]=input_output_uri
os.chdir(os.getcwd())

with open('miniwdl_workflows/Mirai_workflow/Mirai_workflow.inputs.json', 'w') as json_file:
    json.dump(d, json_file)
os.chdir('miniwdl_workflows')
os.chmod('run_Mirai_miniwdl_workflow.sh', stat.S_IRWXU|stat.S_IRWXG|stat.S_IRWXO)
# print(subprocess.call('./run_iCAD_miniwdl_workflow.sh'))