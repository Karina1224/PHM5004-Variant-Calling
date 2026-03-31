#!/bin/bash
# =============================================================================
# SCRIPT: 05_verify_downloads.sh
# PURPOSE: Check all 20 CRAM files downloaded correctly (non-zero size)
# RUN ON:  Login node after Job 03_download_cram.pbs completes
# USAGE:   bash 05_verify_downloads.sh
# =============================================================================

CRAM_DIR=/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/cram

SAMPLES=(
    HG00096 HG00097 HG00099 HG00100
    NA12878 NA12891 NA12892 NA19240
    NA18534 NA18939 HG00553 HG01112
    HG02461 HG03052 HG03713 HG03006
    NA20502 NA20510 NA20518 NA20525
)

echo "Verifying CRAM downloads..."
echo ""

PASS=0
FAIL=0

for SAMPLE in "${SAMPLES[@]}"; do
    CRAM=$CRAM_DIR/${SAMPLE}.cram
    CRAI=$CRAM_DIR/${SAMPLE}.cram.crai

    if [ -f "$CRAM" ] && [ -s "$CRAM" ] && [ -f "$CRAI" ] && [ -s "$CRAI" ]; then
        SIZE=$(ls -lh $CRAM | awk '{print $5}')
        echo "  ✓ $SAMPLE  ($SIZE)"
        PASS=$((PASS+1))
    else
        echo "  ✗ $SAMPLE  MISSING OR EMPTY"
        FAIL=$((FAIL+1))
    fi
done

echo ""
echo "Result: $PASS/20 passed, $FAIL failed"

if [ $FAIL -eq 0 ]; then
    echo "All downloads verified. Ready to run serial pipeline."
else
    echo "Re-run 03_download_cram.pbs to retry failed downloads (wget -c will resume)."
fi
