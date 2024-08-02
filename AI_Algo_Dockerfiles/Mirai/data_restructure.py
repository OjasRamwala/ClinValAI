import sys
import os
import shutil
root = sys.argv[1]
folders_to_be_included=["Digital_Screening_Mammo_with_CAD,_Screening",
                        "L_CC",
                        "L_MLO",
                        "MAMMO_SCREENING_MOBILE",
                        "MAMM_SCREENING_MOBILE",
                        "MAMSCREEN_MOBILE",
                        "MAM_MAMMOGRAPHY_SCREENING",
                        "MAM_MAMMOGRAPHY_UNILAT_SCREEN",
                        "MAM_MAMMOGRAPSSHY_SCREENING",
                        "MAM_MAMMOSSGRAPHY_SCREENING",
                        "MAM_MAMMSSOGRAPHY_SCREENING",
                        "MAM_MOBILE_SCREENING",
                        "MAM_SCERENING_MOBILE",
                        "MAM_SCREEENING_MOBILE",
                        "MAM_SCREEING_MOBILE",
                        "MAM_SCREENING",
                        "MAM_SCREENING_MOBIL",
                        "MAM_SCREENING_MOBILE",
                        "MAM_SCREENING_MOBILE_MAMMO",
                        "MAM_SCREEN_MOBILE",
                        "MAM_SCRENING_MOBILE",
                        "MA_SCREEN_MOBILE",
                        "MM_MAMMOGRAM_UNILATERAL",
                        "MOBILE",
                        "MOBILE_MAMMOGRAM",
                        "MOBILE_MAMM_SCREEN",
                        "MOBILE_SCREENING",
                        "MOBILE_SCREENING_MAMMO",
                        "MOBILE_SCR_MAMM",
                        "Mam_Screening_Mobile",
                        "R_CC",
                        "R_MLO",
                        "SCREEM_MAMM_MOBILE",
                        "SCREENING_MAMMOGRAM",
                        "SCREENING_MAMMOGRAM_MOBILE",
                        "SCREENING_MAMMO_MOBILE",
                        "SCREENING_MOBILE",
                        "SCREENING_MOBILE_MAMMOGRAPHY",
                        "SCREEN_MAMMO_MOBILE",
                        "SCREEN_MAMM_MOBILE",
                        "SCREEN_MAM_MOBILE",
                        "SCREEN_MOBILE_MAMM",
                        "SCR_MAMMO_MOBILE",
                        "SCR_MAMM_MOBILE",
                        "SCR_MAM_MOBILE",
                        "mobile"]

for exam in os.listdir(root):
    if not exam.startswith('.'):
        for folder in os.listdir(os.path.join(root, exam)):
            if not folder.startswith('.'):
                if folder in folders_to_be_included:
                    for image in os.listdir(os.path.join(root, exam, folder)):
                        source=os.path.join(root, exam, folder, image)
                        target=os.path.join(root, exam)
                        shutil.move(source, target)
                    os.rmdir(os.path.join(root, exam, folder))
                else:
                    shutil.rmtree(os.path.join(root, exam, folder))
            else:
                shutil.rmtree(os.path.join(root, exam, folder))
    else:
        shutil.rmtree(os.path.join(root, exam))

# batch = sys.argv[1]
# UC_Davis-specific
# for dirs in os.listdir(batch):
#     if not dirs.startswith('.'):
#         print("*"*10)
#         print(dirs)
#         os.makedirs(os.path.join(str(batch), dirs), exist_ok=True)
#         for exam in os.listdir(os.path.join(os.getcwd(), batch, dirs)):
#             if not exam.startswith('.'):
#                 for image in os.listdir(os.path.join(os.getcwd(), batch, dirs, exam)):
#                     if not image.startswith('.'):
#                         source = os.path.join(os.getcwd(), batch, dirs, exam, image)
#                         target = os.path.join(os.getcwd(), batch, dirs, image)
#                         print(source)
#                         print(target)
#                         shutil.move(source, target)
#                         os.rmdir(os.path.join(os.getcwd(), batch, dirs, exam))

# Partly working code
# root = sys.argv[1]
# for exam in os.listdir(root):
#     if not exam.startswith('.'):
#         print(exam)
#         for folder in os.listdir(os.path.join(root, exam)):
#             if not folder.startswith('.'):
#                 for image in os.listdir(os.path.join(root, exam, folder)):
#                     if not image.startswith('.'):
#                         source=os.path.join(os.path.join(root, exam, folder, image))
#                         target=os.path.join(os.path.join(root, exam))
#                         print(source)
#                         print(target)
#                         shutil.move(source, target)
#         os.rmdir(os.path.join(root, exam, folder))



# folders_to_be_included=['L_CC', 
#                         'L_MLO', 
#                         'MAMSCREEN_MOBILE', 
#                         'MAM_MAMMOGRAPHY_SCREENING',
#                         'MAM_MAMMOGRAPHY_UNILAT_SCREEN', 
#                         'MAM_MAMMOGRAPSSHY_SCREENING',
#                         'MAM_MAMMOSSGRAPHY_SCREENING', 
#                         'MAM_MOBILE_SCREENING',
#                         'MAM_SCREEING_MOBILE', 
#                         'MAM_SCREENING_MOBILE', 
#                         'MAM_SCREEN_MOBILE',
#                         'MA_SCREEN_MOBILE', 
#                         'MOBILE', 
#                         'MOBILE_SCR_MAMM', 
#                         'R_CC', 
#                         'R_MLO',
#                         'SCREEM_MAMM_MOBILE', 
#                         'SCREEN_MAMMO_MOBILE', 
#                         'SCREEN_MAMM_MOBILE',
#                         'SCREEN_MAM_MOBILE', 
#                         'SCR_MAMMO_MOBILE', 
#                         'SCR_MAMM_MOBILE',
#                         'SCR_MAM_MOBILE']