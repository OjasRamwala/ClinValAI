import os
import sys
import csv
import shutil
import random
import pydicom

print("Data Standardization")
print("Test GPU")

def check_laterality (ds):
    if hasattr(ds, 'ImageLaterality'):
        return ds.ImageLaterality
    elif hasattr(ds, 'Laterality'):
        return ds.Laterality
    elif hasattr(ds, 'FrameLaterality'):
        return ds.FrameLaterality
    elif hasattr(ds, 'ProtocolName'):
        return ds.ProtocolName[0]
    elif hasattr(ds, 'SeriesDescription'):
        return ds.SeriesDescription[0]
    else:
        return False

def check_projection(ds):
    if hasattr(ds, 'ViewPosition'):
        return ds.ViewPosition
    else:
        return False
    # elif hasattr(ds, 'ProtocolName'):
    #     return ds.ProtocolName[2:4]

# def check_2D_or_SyntheticSlice(ds):
#     return "2D_MMG" # MAM Screening Digital # MAM Screening w DBT # Empty # Tag Absent

batch = sys.argv[1]

complete_metadata=[]
for exam in os.listdir(batch):
    flag=0
    print(exam)
    print("****")
    L_CC=[]
    L_MLO=[]
    R_CC=[]
    R_MLO=[]
    for image in os.listdir(os.path.join(batch, exam)):
        print(image)
        print("*"*13)
        image_path=os.path.join(batch, exam, image)
        if (not image_path.endswith('.dcm')):
            image_dcm=image_path+'.dcm'
            os.rename(image_path, image_dcm)
        else:
            image_dcm=image_path
        print(image_dcm)
        ds=pydicom.dcmread(image_dcm)
        print("Study Instance UID:", ds.StudyInstanceUID)
        random.seed(hash(ds.StudyInstanceUID))
        if (hasattr(ds, 'pixel_array')): 
            print("*"*4)
            print(ds.pixel_array.shape)
            if (len(ds.pixel_array.shape)==2): # check if 2D
                if (check_laterality(ds) and check_projection(ds)):
                    if (check_laterality(ds)=="L" and check_projection(ds)=="CC") :
                        print("L CC")
                        L_CC.append(image_dcm)
                    elif (check_laterality(ds)=="L" and check_projection(ds)=="MLO") :
                        print("L MLO")
                        L_MLO.append(image_dcm)
                    elif (check_laterality(ds)=="R" and check_projection(ds)=="CC") :
                        print("R CC")
                        R_CC.append(image_dcm)
                    elif (check_laterality(ds)=="R" and check_projection(ds)=="MLO") :
                        print("R MLO")
                        R_MLO.append(image_dcm)
                    else:
                        os.remove(image_dcm)
                else:
                    os.remove(image_dcm)
            else:
                flag=1 # Exam has 3D image
                os.remove(image_dcm)
        else:
            os.remove(image_dcm)
        # check indentation
    if (flag==1):
        print("Removing 3D Exam:", exam)
        shutil.rmtree(os.path.join(batch, exam))
        flag=0
        continue

    print("L CC:", L_CC)
    print("R CC:", R_CC)
    print("L MLO:", L_MLO)
    print("R MLO:", R_MLO)
    
    if ((len(L_CC)==0) or
        (len(R_CC)==0) or
        (len(L_MLO)==0) or
        (len(R_MLO)==0)):
        print("Insufficient Number of Images:", exam)
        shutil.rmtree(os.path.join(batch, exam))
    
    else:
        print("*"*13)
        print("Image Selection for Exam:", exam)
        if (len(L_CC)>0):
            print("L CC: 2D MMG")
            l_cc=random.choice(L_CC)
            # l_cc=L_CC[0]
            for i in L_CC:
                if (i!=l_cc):
                    os.remove(i)
        if (len(R_CC)>0):
            print("R CC: 2D MMG")
            r_cc=random.choice(R_CC)
            # r_cc=R_CC[0]
            for i in R_CC:
                if (i!=r_cc):
                    os.remove(i)
        if (len(L_MLO)>0):
            print("L MLO: 2D MMG")
            l_mlo=random.choice(L_MLO)
            # l_mlo=L_MLO[0]
            for i in L_MLO:
                if (i!=l_mlo):
                    os.remove(i)
        if (len(R_MLO)>0):
            print("R MLO: 2D MMG")
            r_mlo=random.choice(R_MLO)
            # r_mlo=R_MLO[0]
            for i in R_MLO:
                if (i!=r_mlo):
                    os.remove(i)

        for image in ([l_cc, r_cc, l_mlo, r_mlo]):
            image_dcm=image
            image_png_path=image_dcm.replace('.dcm', '.dcm.png')
            ds=pydicom.dcmread(image_dcm)
            if (not hasattr(ds, 'StudyDescription')):
                ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
                ds.save_as(image_dcm)
            if (not hasattr(ds, 'SeriesDescription')):
                ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
                ds.save_as(image_dcm)
            # exam id: ds[0x0010, 0x0020] (example)
            image_metadata=[exam, # ds[0x0020, 0x000d].value,
                           ds[0x0020, 0x000d].value,
                           str(check_laterality(ds)),
                           str(check_projection(ds)), 
                           image_png_path,
                            0, 
                            0, 
                            "test"]
            complete_metadata.append(image_metadata) 
            print("Metadata:", complete_metadata)

print("Complete Metadata:", complete_metadata)

with open('/root/metadata.csv', 'w', newline='') as f:
    writer=csv.writer(f)
    field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
    writer.writerow(field)
    for image_metadata in complete_metadata:
        writer.writerow(image_metadata)

# batch = sys.argv[1]
# complete_metadata=[]
# for exam in os.listdir(batch):
#     print(exam)
#     print("****")
#     L_CC=[]
#     L_MLO=[]
#     R_CC=[]
#     R_MLO=[]
#     for image in os.listdir(os.path.join(batch, exam)):
#         print("*"*13)
#         image_path=os.path.join(batch, exam, image)
#         if (not image_path.endswith('.dcm')):
#             image_dcm=image_path+'.dcm'
#             os.rename(image_path, image_dcm)
#         else:
#             image_dcm=image_path
#         ds=pydicom.dcmread(image_dcm)
#         random.seed(hash(ds.StudyInstanceUID))
#         if (hasattr(ds, 'pixel_array')): 
#             print("*"*4)
#             print(ds.pixel_array.shape)
#             if (len(ds.pixel_array.shape)==2): # check if 2D
#                 if (check_laterality(ds) and check_projection(ds)):
#                     if (check_laterality(ds)=="L" and check_projection(ds)=="CC") :
#                         print("L CC 2D MMG")
#                         L_CC.append(image_dcm)
#                     elif (check_laterality(ds)=="L" and check_projection(ds)=="MLO") :
#                         print("L MLO 2D MMG")
#                         L_MLO.append(image_dcm)
#                     elif (check_laterality(ds)=="R" and check_projection(ds)=="CC") :
#                         print("R CC 2D MMG")
#                         R_CC.append(image_dcm)
#                     elif (check_laterality(ds)=="R" and check_projection(ds)=="MLO") :
#                         print("R MLO 2D MMG")
#                         R_MLO.append(image_dcm)
#                     else:
#                         os.remove(image_dcm)
#                 else:
#                     os.remove(image_dcm)
#             else:
#                 os.remove(image_dcm)
#         else:
#             os.remove(image_dcm)
    
#     print("L CC:", L_CC)
#     print("R CC:", R_CC)
#     print("L MLO:", L_MLO)
#     print("R MLO:", R_MLO)
    
#     if ((len(L_CC)==0) or
#         (len(R_CC)==0) or
#         (len(L_MLO)==0) or
#         (len(R_MLO)==0 )):
#         print("Insufficient Number of Images:", exam)
#         shutil.rmtree(os.path.join(batch, exam))
    
#     else:
#         print("*"*13)
#         print("Image Selection for Exam:", exam)
#         if (len(L_CC)>0):
#             print("L CC: 2D MMG")
#             l_cc=random.choice(L_CC)
#             # l_cc=L_CC[0]
#             for i in L_CC:
#                 if (i!=l_cc):
#                     os.remove(i)
#         if (len(R_CC)>0):
#             print("R CC: 2D MMG")
#             r_cc=random.choice(R_CC)
#             # r_cc=R_CC[0]
#             for i in R_CC:
#                 if (i!=r_cc):
#                     os.remove(i)
#         if (len(L_MLO)>0):
#             print("L MLO: 2D MMG")
#             l_mlo=random.choice(L_MLO)
#             # l_mlo=L_MLO[0]
#             for i in L_MLO:
#                 if (i!=l_mlo):
#                     os.remove(i)
#         if (len(R_MLO)>0):
#             print("R MLO: 2D MMG")
#             r_mlo=random.choice(R_MLO)
#             # r_mlo=R_MLO[0]
#             for i in R_MLO:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)


















# complete_metadata=[]
# for exam in os.listdir(batch):
#     flag=0
#     print("****")
#     L_CC=[]
#     R_CC=[]
#     L_MLO=[]
#     R_MLO=[]
#     for image in os.listdir(os.path.join(batch, exam)):
#         print("*"*13)
#         image_path=os.path.join(batch, exam, image)
#         if (not image_path.endswith('.dcm')):
#             image_dcm=image_path+'.dcm'
#             os.rename(image_path, image_dcm)
#         else:
#             image_dcm=image_path
#         ds=pydicom.dcmread(image_dcm)
#         random.seed(ds.StudyInstanceUID.split('.')[-1])
#         # random.seed(hash(ds.StudyInstanceUID))
#         if (hasattr(ds, 'pixel_array')): 
#             print("*"*4)
#             print(ds.pixel_array.shape)
#             if (len(ds.pixel_array.shape)==2): # check if 2D
#                 if (check_laterality(ds) and check_projection(ds)):
#                     if (check_laterality(ds)=="L" and check_projection(ds)=="CC") :
#                         print("L CC 2D MMG")
#                         L_CC.append(image_dcm)
#                     elif (check_laterality(ds)=="L" and check_projection(ds)=="MLO") :
#                         print("L MLO 2D MMG")
#                         L_MLO.append(image_dcm)
#                     elif (check_laterality(ds)=="R" and check_projection(ds)=="MLO") :
#                         print("R MLO 2D MMG")
#                         R_MLO.append(image_dcm)
#                     elif (check_laterality(ds)=="R" and check_projection(ds)=="CC") :
#                         print("R CC 2D MMG")
#                         R_CC.append(image_dcm)
#                     else:
#                         os.remove(image_dcm)
#                 else:
#                     os.remove(image_dcm)
#             else:
#                 flag=1 # 3D image
#                 os.remove(image_dcm)
#         else:
#             os.remove(image_dcm)
    
#     if (flag==1): # remove an exam that has even a single 3D image
#         shutil.rmtree(os.path.join(batch, exam))
#         flag=0
#         break
    
#     print("L CC:", L_CC)
#     print("R CC:", R_CC)
#     print("L MLO:", L_MLO)
#     print("R MLO:", R_MLO)
    
#     if ((len(L_CC)==0) or
#         (len(R_CC)==0) or
#         (len(L_MLO)==0) or
#         (len(R_MLO)==0)):
#         print("Insufficient Number of Images:", exam)
#         shutil.rmtree(os.path.join(batch, exam))
    
#     else:
#         print("*"*13)
#         print("Image Selection for Exam:", exam)
#         if (len(L_CC)>0):
#             print("L CC: 2D MMG")
#             l_cc=random.choice(L_CC)
#             # l_cc=L_CC[0]
#             for i in L_CC:
#                 if (i!=l_cc):
#                     os.remove(i)
#         if (len(R_CC)>0):
#             print("R CC: 2D MMG")
#             r_cc=random.choice(R_CC)
#             # r_cc=R_CC[0]
#             for i in R_CC:
#                 if (i!=r_cc):
#                     os.remove(i)
#         if (len(L_MLO)>0):
#             print("L MLO: 2D MMG")
#             l_mlo=random.choice(L_MLO)
#             # l_mlo=L_MLO[0]
#             for i in L_MLO:
#                 if (i!=l_mlo):
#                     os.remove(i)
#         if (len(R_MLO)>0):
#             print("R MLO: 2D MMG")
#             # r_mlo=random.choice(R_MLO)
#             r_mlo=R_MLO[0]
#             for i in R_MLO:
#                 if (i!=r_mlo):
#                     os.remove(i)
#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)

# UC_Davis
# def check_2D_or_SyntheticSlice(ds):
#     if ((0x0008, 0x1032) in ds and (0x0008, 0x0104) in ds[0x0008, 0x1032][0]):
#         if (ds[0x0008, 0x1032][0][0x0008, 0x0104].value=='MAMMOGRAPHY SCREENING' or 
#             ds[0x0008, 0x1032][0][0x0008, 0x0104].value=='MAMSCREEN'):
#             return "2D_MMG"
#         elif (ds[0x0008, 0x1032][0][0x0008, 0x0104].value=='MAMMOGRAPHY SCREENING DIGITAL, DIGITAL BREAST TOMOSYNTHESIS, W'):
#             return "SyntheticSlice"
#         else:
#             return 0 # "SyntheticSlice"?
#     else:
#         return 0 # "SyntheticSlice"?

# UNC  
# def check_2D_or_SyntheticSlice(ds):
#     if ((0x0008, 0x1032) in ds and (0x0008, 0x0104) in ds[0x0008, 0x1032][0]):
#         if (ds[0x0008, 0x1032][0][0x0008, 0x0104].value=='MAMMO SCREENING BILATERAL'):
#             return "2D_MMG"
#         elif (ds[0x0008, 0x1032][0][0x0008, 0x0104].value=='MAMMO DIGITAL SCREENING W TOMO BILATERAL W CAD' or
#              ds[0x0008, 0x1032][0][0x0008, 0x0104].value=='MAMMO DIGITAL SCREENING W TOMO BILATERAL'):
#             return "SyntheticSlice"
#         else:
#             return "SyntheticSlice"
#     else:
#         return "SyntheticSlice"
    
# UCSF
# def check_2D_or_SyntheticSlice(ds):
#     return "2D_MMG" # MAM Screening Digital # MAM Screening w DBT # Empty # Tag Absent

    

######### Working Code Begins #########
# complete_metadata=[]
# for exam in os.listdir(batch):
#     print("****")
#     L_CC=[]
#     L_CC_syn=[]
#     L_MLO=[]
#     L_MLO_syn=[]
#     R_CC=[]
#     R_CC_syn=[]
#     R_MLO=[]
#     R_MLO_syn=[]
#     for image in os.listdir(os.path.join(batch, exam)):
#         print("*"*13)
#         image_path=os.path.join(batch, exam, image)
#         if (not image_path.endswith('.dcm')):
#             image_dcm=image_path+'.dcm'
#             os.rename(image_path, image_dcm)
#         else:
#             image_dcm=image_path
#         ds=pydicom.dcmread(image_dcm)
#         if (hasattr(ds, 'pixel_array')): 
#             print("*"*4)
#             print(ds.pixel_array.shape)
#             if (len(ds.pixel_array.shape)==2): # check if 2D
#                 if (check_laterality(ds) and check_projection(ds)):
#                     if (check_laterality(ds)=="L" and check_projection(ds)=="CC") :
#                         if (check_2D_or_SyntheticSlice(ds)=="2D_MMG"):
#                             print("L CC 2D MMG")
#                             L_CC.append(image_dcm)
#                         elif (check_2D_or_SyntheticSlice(ds)=="SyntheticSlice"):
#                             print("L CC 2D SyntheticSlice")
#                             L_CC_syn.append(image_dcm)
#                     elif (check_laterality(ds)=="L" and check_projection(ds)=="MLO") :
#                         if (check_2D_or_SyntheticSlice(ds)=="2D_MMG"):
#                             print("L MLO 2D MMG")
#                             L_MLO.append(image_dcm)
#                         elif (check_2D_or_SyntheticSlice(ds)=="SyntheticSlice"):
#                             print("L MLO 2D SyntheticSlice")
#                             L_MLO_syn.append(image_dcm)
#                     elif (check_laterality(ds)=="R" and check_projection(ds)=="CC") :
#                         if (check_2D_or_SyntheticSlice(ds)=="2D_MMG"):
#                             print("R CC 2D MMG")
#                             R_CC.append(image_dcm)
#                         elif (check_2D_or_SyntheticSlice(ds)=="SyntheticSlice"):
#                             print("R CC 2D SyntheticSlice")
#                             R_CC_syn.append(image_dcm)
#                     elif (check_laterality(ds)=="R" and check_projection(ds)=="MLO") :
#                         if (check_2D_or_SyntheticSlice(ds)=="2D_MMG"):
#                             print("R MLO 2D MMG")
#                             R_MLO.append(image_dcm)
#                         elif (check_2D_or_SyntheticSlice(ds)=="SyntheticSlice"):
#                             print("R MLO 2D SyntheticSlice")
#                             R_MLO_syn.append(image_dcm)
#                     else:
#                         os.remove(image_dcm)
#                 else:
#                     os.remove(image_dcm)
#             else:
#                 os.remove(image_dcm)
#         else:
#             os.remove(image_dcm)
    
#     print("L CC:", L_CC)
#     print("L CC Syn:", L_CC_syn)
#     print("R CC:", R_CC)
#     print("R CC Syn:", R_CC_syn)
#     print("L MLO:", L_MLO)
#     print("L MLO Syn:", L_MLO_syn)
#     print("R MLO:", R_MLO)
#     print("R MLO Syn:", R_MLO_syn)
    
#     if ((len(L_CC)==0 and len(L_CC_syn)==0) or
#         (len(R_CC)==0 and len(R_CC_syn)==0) or
#         (len(L_MLO)==0 and len(L_MLO_syn)==0) or
#         (len(R_MLO)==0 and len(R_MLO_syn)==0)):
#         print("Insufficient Number of Images:", exam)
#         shutil.rmtree(os.path.join(batch, exam))
    
#     else:
#         print("*"*13)
#         print("Image Selection for Exam:", exam)
#         if (len(L_CC)>0):
#             print("L CC: 2D MMG")
#             # l_cc=random.choice(L_CC)
#             l_cc=L_CC[0]
#             for i in L_CC:
#                 if (i!=l_cc):
#                     os.remove(i)
#         else:
#             print("L CC: Syn")
#             # l_cc=random.choice(L_CC_syn)
#             l_cc=L_CC_syn[0]
#             for i in L_CC_syn:
#                 if (i!=l_cc):
#                     os.remove(i)
#         if (len(R_CC)>0):
#             print("R CC: 2D MMG")
#             # r_cc=random.choice(R_CC)
#             r_cc=R_CC[0]
#             for i in R_CC:
#                 if (i!=r_cc):
#                     os.remove(i)
#         else:
#             print("R CC: Syn")
#             # r_cc=random.choice(R_CC_syn)
#             r_cc=R_CC_syn[0]
#             for i in R_CC_syn:
#                 if (i!=r_cc):
#                     os.remove(i)
#         if (len(L_MLO)>0):
#             print("L MLO: 2D MMG")
#             # l_mlo=random.choice(L_MLO)
#             l_mlo=L_MLO[0]
#             for i in L_MLO:
#                 if (i!=l_mlo):
#                     os.remove(i)
#         else:
#             print("L MLO: Syn")
#             # l_mlo=random.choice(L_MLO_syn)
#             l_mlo=L_MLO_syn[0]
#             for i in L_MLO_syn:
#                 if (i!=l_mlo):
#                     os.remove(i)
#         if (len(R_MLO)>0):
#             print("R MLO: 2D MMG")
#             # r_mlo=random.choice(R_MLO)
#             r_mlo=R_MLO[0]
#             for i in R_MLO:
#                 if (i!=r_mlo):
#                     os.remove(i)
#         else:
#             print("R MLO: Syn")
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
######### Working Code Completes #########

#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#             # l_mlo=random.choice(L_MLO_syn)
#             l_mlo=L_MLO_syn[0]
#             for i in L_MLO_syn:
#                 if (i!=l_mlo):
#                     os.remove(i)
#         if (len(R_MLO)>0):
#             print("R MLO: 2D MMG")
#             # r_mlo=random.choice(R_MLO)
#             r_mlo=R_MLO[0]
#             for i in R_MLO:
#                 if (i!=r_mlo):
#                     os.remove(i)
#         else:
#             print("R MLO: Syn")
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#             # l_mlo=random.choice(L_MLO_syn)
#             l_mlo=L_MLO_syn[0]
#             for i in L_MLO_syn:
#                 if (i!=l_mlo):
#                     os.remove(i)
#         if (len(R_MLO)>0):
#             print("R MLO: 2D MMG")
#             # r_mlo=random.choice(R_MLO)
#             r_mlo=R_MLO[0]
#             for i in R_MLO:
#                 if (i!=r_mlo):
#                     os.remove(i)
#         else:
#             print("R MLO: Syn")
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#             # l_mlo=random.choice(L_MLO_syn)
#             l_mlo=L_MLO_syn[0]
#             for i in L_MLO_syn:
#                 if (i!=l_mlo):
#                     os.remove(i)
#         if (len(R_MLO)>0):
#             print("R MLO: 2D MMG")
#             # r_mlo=random.choice(R_MLO)
#             r_mlo=R_MLO[0]
#             for i in R_MLO:
#                 if (i!=r_mlo):
#                     os.remove(i)
#         else:
#             print("R MLO: Syn")
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#             for i in R_MLO:
#                 if (i!=r_mlo):
#                     os.remove(i)
#         else:
#             print("R MLO: Syn")
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#             for i in R_MLO:
#                 if (i!=r_mlo):
#                     os.remove(i)
#         else:
#             print("R MLO: Syn")
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#             # r_mlo=random.choice(R_MLO_syn)
#             r_mlo=R_MLO_syn[0]
#             for i in R_MLO_syn:
#                 if (i!=r_mlo):
#                     os.remove(i)

#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)
#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=image
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x1030), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             if (not hasattr(ds, 'SeriesDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', str(check_laterality(ds)) + " " + str(check_projection(ds)))
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            str(check_laterality(ds)),
#                            str(check_projection(ds)), 
#                            image_png_path,
#                             0, 
#                             0, 
#                             "test"]
#             complete_metadata.append(image_metadata) 
#             print("Metadata:", complete_metadata)

# print("Complete Metadata:", complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)


# elif ((len(L_CC)==0 and len(L_CC_syn)==0) or
#       (len(R_CC)==0 and len(R_CC_syn)==0) or
#       (len(L_MLO)==0 and len(L_MLO_syn)==0) or
#       (len(R_MLO)==0 and len(R_MLO_syn)==0)):
#     print("Insufficient Number of Exams:", exam)
#     shutil.rmtree(os.path.join(batch, exam))

# else:
#     shutil.rmtree(os.path.join(batch, exam)) # need to modify to handle multiple images of same combination

# print(complete_metadata)

# with open('/root/metadata.csv', 'w', newline='') as f:
#     writer=csv.writer(f)
#     field = ["patient_id","exam_id","laterality","view","file_path","years_to_cancer","years_to_last_followup","split_group"]
#     writer.writerow(field)
#     for image_metadata in complete_metadata:
#         writer.writerow(image_metadata)



# if (len(L_CC)>1):
#     for image in L_CC:
#         ds=pydicom.dcmread(image)

# If all are synthetic - select one randomly
# If atleast 1 2D MMG - discard rest
# If more than 1 2D MMG - select one randomly

            
# Prioritize 2D mammograms over synthetic slices
# Exactly 1 LCC, 1 LMLO, 1 RCC, and 1 RMLO


# Image - filter corrupted files

# for exam in os.listdir(batch):
#     L_CC=[]
#     L_CC_syn=[]
#     L_MLO=[]
#     L_MLO_syn=[]
#     R_CC=[]
#     R_CC_syn=[]
#     R_MLO=[]
#     R_MLO_syn=[]
#     for image in os.listdir(os.path.join(batch, exam)):
#         print("*"*13)
#         image_path=os.path.join(batch, exam, image)
#         if (not image_path.endswith('.dcm')):
#             image_dcm=image_path+'.dcm'
#             os.rename(image_path, image_dcm)
#         else:
#             image_dcm=image_path
#         ds=pydicom.dcmread(image_dcm)
#         if (hasattr(ds, 'pixel_array')): 
#             print("*"*4)
#             print(ds.pixel_array.shape)
#             if (len(ds.pixel_array.shape)==2): # check if 2D
#                 if (check_laterality(ds) and check_projection(ds)):
#                     if (check_laterality(ds)=="L" and check_projection(ds)=="CC") :
#                         if (check_2D_or_SyntheticSlice(ds)=="2D_MMG"):
#                             print("L CC 2D MMG")
#                             L_CC.append(image_dcm)
#                         elif (check_2D_or_SyntheticSlice(ds)=="SyntheticSlice"):
#                             print("L CC 2D SyntheticSlice")
#                             L_CC_syn.append(image_dcm)
#                     elif (check_laterality(ds)=="L" and check_projection(ds)=="MLO") :
#                         if (check_2D_or_SyntheticSlice(ds)=="2D_MMG"):
#                             print("L MLO 2D MMG")
#                             L_MLO.append(image_dcm)
#                         elif (check_2D_or_SyntheticSlice(ds)=="SyntheticSlice"):
#                             print("L MLO 2D SyntheticSlice")
#                             L_MLO_syn.append(image_dcm)
#                     elif (check_laterality(ds)=="R" and check_projection(ds)=="CC") :
#                         if (check_2D_or_SyntheticSlice(ds)=="2D_MMG"):
#                             print("R CC 2D MMG")
#                             R_CC.append(image_dcm)
#                         elif (check_2D_or_SyntheticSlice(ds)=="SyntheticSlice"):
#                             print("R CC 2D SyntheticSlice")
#                             R_CC_syn.append(image_dcm)
#                     elif (check_laterality(ds)=="R" and check_projection(ds)=="MLO") :
#                         if (check_2D_or_SyntheticSlice(ds)=="2D_MMG"):
#                             print("R MLO 2D MMG")
#                             R_MLO.append(image_dcm)
#                         elif (check_2D_or_SyntheticSlice(ds)=="SyntheticSlice"):
#                             print("R MLO 2D SyntheticSlice")
#                             R_MLO_syn.append(image_dcm)
#                     else:
#                         os.remove(image_dcm)
#                 else:
#                     os.remove(image_dcm)
#             else:
#                 os.remove(image_dcm)
#         else:
#             os.remove(image_dcm)
    
#     if ((len(L_CC)==0 and len(L_CC_syn)==0) or
#         (len(R_CC)==0 and len(R_CC_syn)==0) or
#         (len(L_MLO)==0 and len(L_MLO_syn)==0) or
#         (len(R_MLO)==0 and len(R_MLO_syn)==0)):
#         print("Insufficient Number of Exams:", exam)
#         shutil.rmtree(os.path.join(batch, exam))
    
#     else:
#         print("Image Selection for Exam:", exam)
#         if (len(L_CC)>0):
#             print("L CC: 2D MMG")
#             l_cc=random.choice(L_CC)
#         else:
#             print("L CC: Syn")
#             l_cc=random.choice(L_CC_syn)
#         if (len(R_CC)>0):
#             print("R CC: 2D MMG")
#             r_cc=random.choice(R_CC)
#         else:
#             print("R CC: Syn")
#             r_cc=random.choice(R_CC_syn)
#         if (len(L_MLO)>0):
#             print("L MLO: 2D MMG")
#             l_mlo=random.choice(L_MLO)
#         else:
#             print("L MLO: Syn")
#             l_mlo=random.choice(L_MLO_syn)
#         if (len(R_MLO)>0):
#             r_mlo=random.choice(R_MLO)
#         else:
#             r_mlo=random.choice(R_MLO_syn)
        
#         for image in ([l_cc, r_cc, l_mlo, r_mlo]):
#             image_dcm=os.path.join(batch, exam, image)
#             image_png_path=image_dcm.replace('.dcm', '.dcm.png')
#             ds=pydicom.dcmread(image_dcm)
#             if (not hasattr(ds, 'StudyDescription')):
#                 ds.add_new((0x0008, 0x103e), 'LO', 'MAM MAMMOGRAPHY SCREENING')
#                 ds.save_as(image_dcm)
#             image_metadata=[ds[0x0010, 0x0020].value,
#                            ds[0x0020, 0x000d].value,
#                            ds.ImageLaterality,
#                            ds.ViewPosition, 
#                            image_png_path,
#                             0, 
#                             10, 
#                             "test"]
#             complete_metadata.append(image_metadata)

    

        

    
    
    
    # if (len(L_CC)==1 and len(L_MLO)==1 and len(R_CC)==1 and len(R_MLO)==1):
    #     print("Perfect Exam:", exam)
    #     for image in os.listdir(os.path.join(batch, exam)):
    #         image_dcm=os.path.join(batch, exam, image)
    #         image_png_path=image_dcm.replace('.dcm', '.dcm.png')
    #         ds=pydicom.dcmread(image_dcm)
    #         if (not hasattr(ds, 'StudyDescription')):
    #             ds.add_new((0x0008, 0x103e), 'LO', 'MAM MAMMOGRAPHY SCREENING')
    #             ds.save_as(image_dcm)
    #         image_metadata=[ds[0x0010, 0x0020].value,
    #                        ds[0x0020, 0x000d].value,
    #                        ds.ImageLaterality,
    #                        ds.ViewPosition, 
    #                        image_png_path,
    #                         0, 
    #                         10, 
    #                         "test"]
    #         complete_metadata.append(image_metadata)

    # else:
    #     shutil.rmtree(os.path.join(batch, exam)) # need to modify to handle multiple images of same combination