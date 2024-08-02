import sys
import pandas as pd
import boto3
from datetime import datetime

original_path=sys.argv[1]
input_path=sys.argv[2]
in_l=input_path.split('/')
output_path=sys.argv[3]
out_l=output_path.split('/')

workflowID=original_path.split("/")[3]
print("workflowID: ", workflowID)

date_time=datetime.now().strftime("%d_%m_%Y_%H_%M_%S")
print("Date_Time:", date_time)

d={"Workflow_ID":[workflowID],
   "Date_Time":[date_time], 
   "InputS3URI":[input_path],
   "OutputS3URI":[output_path]}


df=pd.DataFrame(d)
df.to_csv('/root/workflow_input_output.csv', index=False)

# field = ["Workflow_ID","InputS3URI","OutputS3URI"]
# row = [[workflowID, input_path, output_path]]


# with open('/root/workflow_input_output.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     writer.writerow(field)
#     writer.writerow(row)

session=boto3.Session()
s3=session.client('s3')
s3.upload_file('/root/workflow_input_output.csv', 
               str(out_l[2]), 
               '/'.join(out_l[3:]) + '/' + in_l[-1][:-4] + '/' + in_l[-1][:-4]  + "_workflow_input_output_" + str(date_time) + ".csv")