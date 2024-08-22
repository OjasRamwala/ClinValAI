# ClinValAI: A framework for developing Cloud-based infrastructures for the External Clinical Validation of AI in Medical Imaging

# Introduction
This repository was used to build ClinValAI, a cloud-agnostic unified framework for establishing robust infrastructures to validate AI algorithms in medical imaging. By featuring dedicated workflows for data ingestion, algorithm scoring, and output processing, we propose an easily customizable method to validate AI models, assess their generalizability, and investigate latent biases. 

# Reproducing ClinValAI

- AI_Algo_Dockerfiles: Scripts to enable the customization of docker images to facilitate the execution of input auditing, data standardization, data restructuring, algorithm inferencing, and score extraction.

- miniwdl_workflows: Scripts for workflow representation, job scheduling, and batch processing orchestration mechanisms.

- Statistical_Analysis: Scripts to perform rigorous external validation of MIRAI, a state-of-the-art deep learning algorithm that predicts future breast cancer risk across five years by processing the four standard views of a 2D digital mammogram – Cranio-Caudal and Medio-Lateral Oblique views of the left and right breast.