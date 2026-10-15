nextflow.enable.dsl = 2

params.gpu = false
params.gpu_image = null
params.exercise_fallback = false

process CPU_PROBE {
    container 'ubuntu:24.04'
    output:
    stdout
    script:
    """
    echo 'attempt=${task.attempt} queue=${task.queue}'
    echo "batch_job_id=\$AWS_BATCH_JOB_ID"
    uname -m
    if [[ '${params.exercise_fallback}' == 'true' && ${task.attempt} == 1 ]]; then exit 143; fi
    """
}

process GPU_PROBE {
    accelerator 1
    container params.gpu_image
    output:
    stdout
    script:
    """
    echo 'attempt=${task.attempt} queue=${task.queue}'
    echo "batch_job_id=\$AWS_BATCH_JOB_ID"
    uname -m
    nvidia-smi --query-gpu=name,driver_version --format=csv
    if [[ '${params.exercise_fallback}' == 'true' && ${task.attempt} == 1 ]]; then exit 143; fi
    """
}

workflow {
    if (params.gpu) {
        if (!params.gpu_image) error 'Supply an approved CUDA image with nvidia-smi via --gpu_image'
        GPU_PROBE().view()
    } else {
        CPU_PROBE().view()
    }
}
