import os
import sys
import json
import boto3
import pandas as pd

csv_file = sys.argv[1]
session=boto3.Session()
s3=session.client('s3')
input_path=sys.argv[2]
in_l=input_path.split('/')
output_path=sys.argv[3]
out_l=output_path.split('/')

s3.upload_file(csv_file, 
               str(out_l[2]), 
               '/'.join(out_l[3:]) + '/' + in_l[-1][:-4] + '/' + in_l[-1][:-4]  + "_scores.csv")