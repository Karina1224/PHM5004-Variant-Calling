#!/bin/bash
# =============================================================================
# SCRIPT: 00_initial_infrastructure.sh
# PURPOSE: Initial project setup — storage migration, conda environment,
#          reference genome indexing (captures work done on Day 0 / Mar 30)
# RUN ON:  Login node (atlas9-c01), run directly
# AUTHOR:  Member A (Infrastructure)
# DATE:    2026-03-30
#
# WHAT THIS SCRIPT DOCUMENTS:
#   1. Project directory structure creation
#   2. Home → /hpctmp storage migration (home quota: 20GB)
#   3. Conda environment setup
#   4. samtools faidx index for hg38
#   5. GATK sequence dictionary creation
#   NOTE: BWA 0.7.17 index is a separate PBS job (see 02_bwa_index.pbs)
#         because it takes ~2 hours and must not run on the login node
# =============================================================================

set -e   # exit on any error

BASE=/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling
REF=$BASE/reference/hg38.fa

echo "========================================"
echo "PHM5004 Infrastructure Setup"
echo "Date: $(date)"
echo "========================================"

# ── Step 1: Create directory structure ───────────────────────────────────────
echo "[1/5] Creating directory structure under /hpctmp..."

mkdir -p $BASE/reference
mkdir -p $BASE/cram
mkdir -p $BASE/output/serial/fastq
mkdir -p $BASE/output/serial/bam
mkdir -p $BASE/output/serial/gvcf
mkdir -p $BASE/output/parallel/gvcf
mkdir -p $BASE/output/joint
mkdir -p $BASE/scripts
mkdir -p $BASE/logs
mkdir -p $BASE/tmp

echo "  Done. Structure:"
find $BASE -type d | sort

# ── Step 2: Storage migration ─────────────────────────────────────────────────
# NOTE: This step is documented here for reproducibility.
# The actual migration was performed manually:
#
#   mv ~/PHM5004_Project /hpctmp/e1520562/
#   ln -s /hpctmp/e1520562/PHM5004_Project ~/PHM5004_Project
#
# Reason: /home quota is only 20GB. Reference genome alone is 3.1GB,
# BWA index files add ~12GB, CRAM files ~100GB — far exceeds home quota.
# /hpctmp has 410TB available (378TB free as of 2026-03-31).
#
echo "[2/5] Storage: project located at $BASE"
echo "  Home usage:  $(df -h /home/svu/e1520562 | tail -1 | awk '{print $3"/"$2}')"
echo "  hpctmp free: $(df -h /hpctmp | tail -1 | awk '{print $4}')"

# ── Step 3: Conda environment ─────────────────────────────────────────────────
# NOTE: Environment 'variant_calling' was created manually.
# Recreate with:
#
#   ~/miniconda3/bin/conda create -n variant_calling -c bioconda \
#     samtools=1.9 picard -y
#
# Then activate with:
#   source /home/svu/e1520562/miniconda3/bin/activate variant_calling
#
# IMPORTANT: bwa-mem2 was attempted but FAILED on NUS HPC due to
# old system libstdc++ (missing CXXABI_1.3.8, CXXABI_1.3.9, GLIBCXX_3.4.21)
# Use HPC module bwa/0.7.17 instead (see all pipeline scripts).
#
echo "[3/5] Conda environment: variant_calling"
echo "  Activate with: source /home/svu/e1520562/miniconda3/bin/activate variant_calling"
echo "  Note: Use 'module load bwa/0.7.17' for BWA — NOT bwa-mem2 (incompatible with HPC)"

# ── Step 4: samtools fai index ────────────────────────────────────────────────
echo "[4/5] Building samtools fai index for hg38..."
module load samtools

if [ ! -f "${REF}.fai" ]; then
    samtools faidx $REF
    echo "  Done: $(ls -lh ${REF}.fai)"
else
    echo "  Already exists: $(ls -lh ${REF}.fai)"
fi

# ── Step 5: GATK sequence dictionary ─────────────────────────────────────────
# IMPORTANT LESSONS LEARNED:
#   - samtools dict produces 0-byte file on NUS HPC (known issue with v1.9)
#     → Use GATK CreateSequenceDictionary instead
#   - Must delete existing .dict before running (GATK will not overwrite)
#   - Must use FULL ABSOLUTE PATHS — relative paths cause GATK 4.0.2.1 to fail
#     with misleading "File not found" error
#
echo "[5/5] Building GATK sequence dictionary..."
module load gatk

DICT=$BASE/reference/hg38.dict
if [ -f "$DICT" ] && [ -s "$DICT" ]; then
    echo "  Already exists: $(ls -lh $DICT)"
else
    [ -f "$DICT" ] && rm $DICT   # remove if 0-byte
    gatk CreateSequenceDictionary \
        -R $BASE/reference/hg38.fa \
        -O $BASE/reference/hg38.dict
    echo "  Done: $(ls -lh $DICT)"
fi

# ── Final verification ────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "Setup complete. Reference files:"
ls -lh $BASE/reference/
echo ""
echo "Next steps:"
echo "  qsub scripts/02_bwa_index.pbs      # Build BWA 0.7.17 index (~2h)"
echo "  qsub scripts/03_download_cram.pbs  # Download 20 CRAM files (~6-8h)"
echo "========================================"
