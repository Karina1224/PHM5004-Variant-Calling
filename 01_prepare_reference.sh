#!/bin/bash
# =============================================================================
# SCRIPT: 01_prepare_reference.sh
# PURPOSE: Build samtools fai index and GATK sequence dictionary for hg38
# RUN ON:  Login node (atlas9-c01), run directly — completes in <5 minutes
# USAGE:   bash 01_prepare_reference.sh
# NOTE:    hg38.fa must already be present in the reference/ directory
#          BWA index is built separately via 02_bwa_index.pbs
# =============================================================================

BASE=/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling
REF=$BASE/reference/hg38.fa

# ── Load modules ─────────────────────────────────────────────────────────────
module load samtools
module load gatk

# ── Step 1: samtools fai index ───────────────────────────────────────────────
echo "[$(date)] Building samtools fai index..."
samtools faidx $REF
echo "[$(date)] fai index done: $(ls -lh ${REF}.fai)"

# ── Step 2: GATK sequence dictionary ────────────────────────────────────────
# NOTE: Must use full absolute paths — relative paths cause GATK 4.0.2.1 to fail
# NOTE: Must delete existing .dict before running (GATK will not overwrite)
echo "[$(date)] Building GATK sequence dictionary..."

if [ -f "${REF%.fa}.dict" ]; then
    rm ${REF%.fa}.dict
    echo "Removed existing .dict file"
fi

gatk CreateSequenceDictionary \
    -R $BASE/reference/hg38.fa \
    -O $BASE/reference/hg38.dict

echo "[$(date)] Dictionary done: $(ls -lh $BASE/reference/hg38.dict)"

# ── Verify ───────────────────────────────────────────────────────────────────
echo ""
echo "Reference files ready:"
ls -lh $BASE/reference/
