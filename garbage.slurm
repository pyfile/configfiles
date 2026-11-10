#!/bin/bash
#SBATCH --nodes=1                   # 节点数
#SBATCH --ntasks=1                  # 任务数
#SBATCH --ntasks-per-node=1         # 每节点的任务数
##SBATCH --mem=64G
##SBATCH --mem-per-cpu=

#SBATCH -J JOB_NAME
#SBATCH -p PARTITION
##SBATCH --qos=high
#SBATCH -o out
#SBATCH -e err
#SBATCH --cpus-per-task=12          # 每任务核心数
#SBATCH --gpus=1                    # 作业申请的总GPU数
##SBATCH -gres=gpu:number           # 每个节点申请number个GPU
##SBATCH --gpus-per-node=number     # 每个节点申请的GPU数
###SBATCH --gpus-per-node=<gpu_type>:<gpu_number>   # 可以指定GPU类型
##SBATCH --gres=gpu:rtx_5090:1,gpu:rtx_pro_6000:3   # 支持混用


# 设置 OpenMP 线程数与申请的核数一致
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# MPI 程序推荐用 srun 启动，它会自动把任务分布到各节点
apptainer exec --cleanenv --no-home --nv \
  --env SLURM_JOB_CPUS_PER_NODE="$SLURM_JOB_CPUS_PER_NODE" \
  --env SLURM_CPUS_ON_NODE="$SLURM_CPUS_ON_NODE" \
  --env SLURM_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK" \
  --env SLURM_NTASKS="$SLURM_NTASKS" \
  --bind /your/code/src:/workspace \
  --pwd /workspace/src \
  /your/container/dir/container.sif \
  python main.py
