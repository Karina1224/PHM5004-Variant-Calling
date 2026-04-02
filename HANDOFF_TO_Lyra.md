# PHM5004 — VCF Analysis Handoff
## To: Lyra
## From:Karina
---

## ✅ What's Already Done for You

All 20 samples have been processed through the serial pipeline.
Your job is to **analyse the variant calls** and **validate the results**.

| Resource | Status | Path on NUS HPC |
|----------|--------|-----------------|
| 20x GVCF files | ✅ Ready | `.../output/serial/gvcf/${SAMPLE}.g.vcf.gz` |
| GVCF index (.tbi) | ✅ Ready | `.../output/serial/gvcf/${SAMPLE}.g.vcf.gz.tbi` |
| Reference genome | ✅ Ready | `.../reference/hg38.fa` |

**Full base path:**
```
/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/
```

---

## 📋 Your Task — 3 Steps

```
Step 1: Run bcftools stats on all 20 GVCFs  →  output/stats/*.stats.txt
Step 2: Parse stats into a clean CSV table   →  output/variant_summary.csv
Step 3: Validate + produce figures           →  output/fig_*.png
```

---

## Step 1 — Run bcftools stats on HPC

Submit as a PBS job — the script loops through all 20 samples automatically.

**Submit:**
```bash
qsub scripts/01_variant_stats.pbs
qstat -u e1520562   # check status
```

**What it runs per sample:**
```bash
module load samtools   # includes bcftools on NUS HPC

bcftools stats \
    --fasta-ref /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/reference/hg38.fa \
    /hpctmp/e1520562/.../output/serial/gvcf/${SAMPLE}.g.vcf.gz \
    > /hpctmp/e1520562/.../output/stats/${SAMPLE}.stats.txt
```

**When done, verify:**
```bash
ls /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/output/stats/
# Should see 20 x .stats.txt files

# Quick check on one sample
grep "^SN" output/stats/NA12878.stats.txt | grep -E "SNPs|indels|Ti/Tv"
```

---

## Step 2 — Parse Results into CSV

Run on HPC login node — fast, no job submission needed:

```bash
python scripts/02_tidy_results.py
```

Reads all 20 `.stats.txt` files and extracts SNP counts, indel counts, and Ti/Tv ratio into one clean table.

**Output:** `output/variant_summary.csv`

**Preview:**
```bash
head -3 output/variant_summary.csv
# sample,population,superpop,n_snps,n_indels,titv_ratio,...
```

---

## Step 3 — Validate & Produce Figures

```bash
python scripts/03_validate_vs_1000G.py
```

**Key validation logic:**
```python
EXPECTED_TITV  = 2.8    # published 1000 Genomes exome value
TITV_TOLERANCE = 0.4    # acceptable range: 2.4 – 3.2

# Each sample is flagged PASS or FAIL automatically
status = "PASS" if abs(titv_ratio - EXPECTED_TITV) <= TITV_TOLERANCE else "FAIL"
```

> **Why Ti/Tv?**
> Transitions (A↔G, C↔T) occur more often than transversions in real biology.
> Exome data expects Ti/Tv ≈ 2.8. Too low = false positives; too high = alignment issues.
> This is the standard quality check for variant calling pipelines.

**Figures produced automatically:**

| File | Description |
|------|-------------|
| `fig_variant_counts.png` | SNPs & indels per sample, coloured by superpopulation |
| `fig_titv_ratio.png` | Ti/Tv per sample vs expected 2.8, red line = reference |
| `fig_snp_indel_pie.png` | Overall variant composition across all 20 samples |
| `validation_report.txt` | PASS/FAIL per sample |

---

## 📤 What to Send the Group When Done

### → Amanda
The **3 PNG figures** — she'll add them to the benchmark slides.

### → summer
These **4 numbers** for Results/Interpretation:
- Mean SNPs per sample
- Mean indels per sample
- Mean Ti/Tv ratio (vs expected 2.8)
- How many samples PASS (e.g. "19/20")

**Template sentence for summer to use:**
> *"Across 20 exome samples, a mean of X,XXX SNPs and X,XXX indels were identified
> per sample. The mean Ti/Tv ratio of X.XX is consistent with the expected value of
> 2.8 for exome sequencing (1000 Genomes Project Consortium, 2015), with X/20 samples
> falling within the acceptable range, confirming pipeline accuracy."*

### → xida
The **3 figures** + this 2-line slide caption:
> *"All 20 variant call sets validated against published 1000 Genomes statistics.
> Mean Ti/Tv = X.XX (expected ~2.8). Results confirm pipeline accuracy."*

---

## 🧬 Sample List

| Sample | Population | Superpop |
|--------|-----------|---------|
| HG00096, HG00097, HG00099, HG00100 | GBR | EUR |
| NA12878, NA12891, NA12892 | CEU | EUR |
| NA20502, NA20510, NA20518, NA20525 | TSI | EUR |
| NA19240, HG02461, HG03052 | YRI/GWD/MSL | AFR |
| NA18534, NA18939 | CHB/JPT | EAS |
| HG03713, HG03006 | ITU/BEB | SAS |
| HG00553, HG01112 | PUR/CLM | AMR |

---

## ⚠️ HPC Notes

```bash
# Scheduler is PBS — use qsub not sbatch
qsub scripts/01_variant_stats.pbs
qstat -u e1520562    # R=running, Q=queued

# Python scripts run on login node (no qsub needed)
python scripts/02_tidy_results.py
python scripts/03_validate_vs_1000G.py

# Install packages if needed
~/miniconda3/bin/pip install pandas matplotlib
```

---

## 📚 Reference

1000 Genomes Project Consortium (2015). A global reference for human genetic variation. *Nature*, 526, 68–74.
- Expected exome Ti/Tv: **~2.8**
- Expected exome SNPs per sample: **~50,000–100,000**
- Expected exome indels per sample: **~5,000–15,000**
