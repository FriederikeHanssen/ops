"""Constants and configuration values for AWS Megatests infrastructure."""

# AWS Configuration
AWS_REGION = "eu-west-1"
S3_BUCKET_NAME = "nf-core-awsmegatests"
S3_WORK_DIR = f"s3://{S3_BUCKET_NAME}"

# Seqera Configuration
SEQERA_API_URL = "https://api.cloud.seqera.io"

# Compute Environment Names
COMPUTE_ENV_NAMES = {
    "cpu": "aws_ireland_fusionv2_nvme_cpu_snapshots",
    "gpu": "aws_ireland_fusionv2_nvme_gpu_snapshots",
    "arm": "aws_ireland_fusionv2_nvme_cpu_ARM_snapshots",
    "s3": "aws_ireland_s3_cpu",
}

# On-demand fallback Compute Environment Names
COMPUTE_ENV_NAMES_ONDEMAND = {
    "cpu_ondemand": "aws_ireland_fusionv2_nvme_cpu_ondemand",
    "gpu_ondemand": "aws_ireland_fusionv2_nvme_gpu_ondemand",
    "s3_ondemand": "aws_ireland_s3_cpu_ondemand",
}

# Compute Environment Descriptions
COMPUTE_ENV_DESCRIPTIONS = {
    "cpu": "CPU compute environment with Fusion v2 and NVMe storage",
    "gpu": "GPU compute environment with Fusion v2 and NVMe storage",
    "arm": "ARM CPU compute environment with Fusion v2 and NVMe storage",
    "s3": "CPU compute environment with S3 storage (no Fusion)",
}

# On-demand fallback Compute Environment Descriptions
COMPUTE_ENV_DESCRIPTIONS_ONDEMAND = {
    "cpu_ondemand": "CPU on-demand fallback compute environment with Fusion v2 and NVMe storage",
    "gpu_ondemand": "GPU on-demand fallback compute environment with Fusion v2 and NVMe storage",
    "s3_ondemand": "CPU on-demand fallback compute environment with S3 storage (no Fusion)",
}

# Configuration File Paths
CONFIG_FILES = {
    "cpu": "seqerakit/current-env-cpu.json",
    "gpu": "seqerakit/current-env-gpu.json",
    "arm": "seqerakit/current-env-cpu-arm.json",
    "s3": "seqerakit/current-env-cpu-s3.json",
}

# On-demand fallback Configuration File Paths
CONFIG_FILES_ONDEMAND = {
    "cpu_ondemand": "seqerakit/current-env-cpu-ondemand.json",
    "gpu_ondemand": "seqerakit/current-env-gpu-ondemand.json",
    "s3_ondemand": "seqerakit/current-env-cpu-s3-ondemand.json",
}

# Nextflow configuration files for compute environments
NEXTFLOW_CONFIG_FILES = {
    "cpu": "seqerakit/configs/nextflow-cpu.config",
    "gpu": "seqerakit/configs/nextflow-gpu.config",
    "arm": "seqerakit/configs/nextflow-arm.config",
    "s3": "seqerakit/configs/nextflow-cpu-s3.config",
}

# On-demand fallback Nextflow configuration files
NEXTFLOW_CONFIG_FILES_ONDEMAND = {
    "cpu_ondemand": "seqerakit/configs/nextflow-cpu-ondemand.config",
    "gpu_ondemand": "seqerakit/configs/nextflow-gpu-ondemand.config",
    "s3_ondemand": "seqerakit/configs/nextflow-cpu-s3-ondemand.config",
}

# TowerForge Configuration
TOWERFORGE_USER_NAME = "TowerForge-AWSMegatests"
TOWERFORGE_POLICY_NAMES = {
    "forge": "TowerForge-Forge-Policy",
    "launch": "TowerForge-Launch-Policy",
    "s3": "TowerForge-S3-Policy",
}

TOWERFORGE_CREDENTIAL_NAME = "TowerForge-AWSMegatests-Dynamic"
TOWERFORGE_CREDENTIAL_DESCRIPTION = (
    "Dynamically created TowerForge credentials for AWS Megatests compute environments"
)

# GitHub Configuration
GITHUB_ORG = "nf-core"
GITHUB_VARIABLE_NAMES = {
    "cpu": "TOWER_COMPUTE_ENV_CPU",
    "gpu": "TOWER_COMPUTE_ENV_GPU",
    "arm": "TOWER_COMPUTE_ENV_ARM",
    "s3": "TOWER_COMPUTE_ENV_S3",
    "cpu_ondemand": "TOWER_COMPUTE_ENV_CPU_ONDEMAND",
    "gpu_ondemand": "TOWER_COMPUTE_ENV_GPU_ONDEMAND",
    "s3_ondemand": "TOWER_COMPUTE_ENV_S3_ONDEMAND",
    "workspace_id": "TOWER_WORKSPACE_ID",
    "s3_bucket": "AWS_S3_BUCKET",
}

# Timeout Configuration (in minutes)
TIMEOUTS = {
    "seqera_credential_create": "5m",
    "seqera_credential_update": "5m",
    "seqera_credential_delete": "2m",
    "compute_env_create": "10m",
    "compute_env_update": "10m",
    "compute_env_delete": "5m",
}

# Default Compute Environment Settings
DEFAULT_COMPUTE_ENV_CONFIG = {
    "region": AWS_REGION,
    "workDir": S3_WORK_DIR,
    "waveEnabled": True,
    "fusion2Enabled": True,
    "nvnmeStorageEnabled": True,
    "fusionSnapshots": True,
    "nextflowConfig": "",
}

DEFAULT_FORGE_CONFIG = {
    "type": "SPOT",
    "minCpus": 0,
    "maxCpus": 1000,
    "gpuEnabled": False,
    "instanceTypes": [],
    "subnets": [],
    "securityGroups": [],
    "disposeOnDeletion": True,
    "allowBuckets": [],
    "efsCreate": False,
    "ebsBootSize": 50,
    "fargateHeadEnabled": True,
    "arm64Enabled": False,
}

# Error Messages
ERROR_MESSAGES = {
    "missing_tower_token": (
        "TOWER_ACCESS_TOKEN is required for Seqera provider. "
        "Please ensure it's set in your ESC environment with proper permissions: "
        "WORKSPACE_ADMIN or COMPUTE_ENV_ADMIN scope."
    ),
    "seqera_provider_init_failed": (
        "Seqera provider initialization failed. "
        "This usually indicates token permissions issues. "
        "Ensure your TOWER_ACCESS_TOKEN has WORKSPACE_ADMIN or COMPUTE_ENV_ADMIN permissions."
    ),
    "config_file_not_found": "Configuration file not found: {}",
    "invalid_json": "Invalid JSON in configuration file {}: {}",
    "config_load_failed": "Failed to load configuration file {}: {}",
    "invalid_workspace_id": "Invalid or missing workspace ID: {}",
    "missing_compute_env_params": "Missing required parameters for compute environment {}",
    "missing_config_args": "Configuration arguments are required for compute environment {}",
    "compute_env_create_failed": (
        "Failed to create compute environment '{}'. "
        "Common causes: "
        "1. Seqera API token lacks required permissions (403 Forbidden) "
        "2. Invalid credentials_id reference "
        "3. Workspace access restrictions "
        "4. Network connectivity issues"
    ),
    "credential_upload_failed": (
        "Failed to upload credentials to Seqera Platform. "
        "Common causes: "
        "1. Seqera provider not properly configured "
        "2. Invalid workspace ID "
        "3. Network connectivity issues to api.cloud.seqera.io "
        "4. Invalid AWS credentials format"
    ),
}

# Required Environment Variables
REQUIRED_ENV_VARS = [
    "TOWER_ACCESS_TOKEN",
    "TOWER_WORKSPACE_ID",
    "GITHUB_TOKEN",
]

# Optional Environment Variables with Defaults
DEFAULT_ENV_VARS = {
    "TOWER_WORKSPACE_ID": "59994744926013",  # Fallback workspace ID
}
