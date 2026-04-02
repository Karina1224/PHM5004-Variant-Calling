# PHM5004 — VCF Analysis Handoff
## To: Member D (Data Analyst — Variant Statistics)
## From: Member A (Serial Baseline)
## Date: 2026-04-02

---

## What You Have Access To

All 20 GVCF files are ready on NUS HPC:
```
/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/output/serial/gvcf/
```

| Sample | GVCF Size | Sample | GVCF Size |
|--------|-----------|--------|-----------|
| HG00096 | 4.5MB | NA18534 | 15MB |
| HG00097 | 14MB  | NA18939 | 26MB |
| HG00099 | 17MB  | HG00553 | 22MB |
| HG00100 | 57MB  | HG01112 | 27MB |
| NA12878 | 33MB  | HG02461 | 7.6MB |
| NA12891 | 57MB  | HG03052 | 7.8MB |
| NA12892 | 16MB  | HG03713 | 6.2MB |
| NA19240 | 1.8MB | HG03006 | 9.8MB |
| NA20502 | 30MB  | NA20510 | 4.6MB |
| NA20518 | 20MB  | NA20525 | 17MB |

---

## Step 1: Joint Genotyping (Submit on HPC first)

Run this before any analysis — merges all 20 GVCFs into one joint VCF:

```bash
cat > /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/scripts/06_joint_genotyping.pbs << 'EOF'
#!/bin/bash
#PBS -N joint_genotyping
#PBS -q parallel
#PBS -o /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/logs/joint_genotyping.log
#PBS -e /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/logs/joint_genotyping.err
#PBS -l walltime=12:00:00
#PBS -l mem=48gb
#PBS -l ncpus=12

module load gatk

BASE=/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling
REF=$BASE/reference/hg38.fa
GVCF_DIR=$BASE/output/serial/gvcf
JOINT_DIR=$BASE/output/joint
mkdir -p $JOINT_DIR/db $BASE/tmp

SAMPLES=(HG00096 HG00097 HG00099 HG00100 NA12878 NA12891 NA12892 NA19240
         NA18534 NA18939 HG00553 HG01112 HG02461 HG03052 HG03713 HG03006
         NA20502 NA20510 NA20518 NA20525)

V_ARGS=""
for S in "${SAMPLES[@]}"; do
    V_ARGS="$V_ARGS -V $GVCF_DIR/${S}.g.vcf.gz"
done

echo "Step 1: GenomicsDBImport $(date)"
gatk GenomicsDBImport $V_ARGS \
    --genomicsdb-workspace-path $JOINT_DIR/db \
    -L chr1 -L chr2 -L chr3 -L chr4 -L chr5 \
    -L chr6 -L chr7 -L chr8 -L chr9 -L chr10 \
    -L chr11 -L chr12 -L chr13 -L chr14 -L chr15 \
    -L chr16 -L chr17 -L chr18 -L chr19 -L chr20 \
    -L chr21 -L chr22 \
    --tmp-dir $BASE/tmp

echo "Step 2: GenotypeGVCFs $(date)"
gatk GenotypeGVCFs \
    -R $REF \
    -V gendb://$JOINT_DIR/db \
    -O $JOINT_DIR/all20_genotyped.vcf.gz \
    --tmp-dir $BASE/tmp

echo "Step 3: Hard filtering SNPs $(date)"
gatk SelectVariants -R $REF -V $JOINT_DIR/all20_genotyped.vcf.gz \
    --select-type-to-include SNP -O $JOINT_DIR/snps_raw.vcf.gz
gatk VariantFiltration -R $REF -V $JOINT_DIR/snps_raw.vcf.gz \
    --filter-expression "QD < 2.0"  --filter-name "QD2" \
    --filter-expression "FS > 60.0" --filter-name "FS60" \
    --filter-expression "MQ < 40.0" --filter-name "MQ40" \
    --filter-expression "SOR > 3.0" --filter-name "SOR3" \
    -O $JOINT_DIR/snps_filtered.vcf.gz

echo "Step 4: Hard filtering Indels $(date)"
gatk SelectVariants -R $REF -V $JOINT_DIR/all20_genotyped.vcf.gz \
    --select-type-to-include INDEL -O $JOINT_DIR/indels_raw.vcf.gz
gatk VariantFiltration -R $REF -V $JOINT_DIR/indels_raw.vcf.gz \
    --filter-expression "QD < 2.0"   --filter-name "QD2" \
    --filter-expression "FS > 200.0" --filter-name "FS200" \
    --filter-expression "SOR > 10.0" --filter-name "SOR10" \
    -O $JOINT_DIR/indels_filtered.vcf.gz

echo "Done: $(date)"
ls -lh $JOINT_DIR/
EOF

qsub /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/scripts/06_joint_genotyping.pbs
qstat -u e1520562
```

---

## Step 2: Collect Stats (PBS job on HPC)

```bash
cat > /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/scripts/07_variant_stats.pbs << 'EOF'
#!/bin/bash
#PBS -N variant_stats
#PBS -q parallel
#PBS -o /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/logs/variant_stats.log
#PBS -e /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/logs/variant_stats.err
#PBS -l walltime=04:00:00
#PBS -l mem=16gb
#PBS -l ncpus=12

module load samtools

BASE=/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling
GVCF_DIR=$BASE/output/serial/gvcf
JOINT_DIR=$BASE/output/joint
STATS_DIR=$BASE/output/stats
mkdir -p $STATS_DIR

SAMPLES=(HG00096 HG00097 HG00099 HG00100 NA12878 NA12891 NA12892 NA19240
         NA18534 NA18939 HG00553 HG01112 HG02461 HG03052 HG03713 HG03006
         NA20502 NA20510 NA20518 NA20525)

echo "sample,total_records,snps,indels,titv_ratio" > $STATS_DIR/per_sample_stats.csv
for S in "${SAMPLES[@]}"; do
    bcftools stats $GVCF_DIR/${S}.g.vcf.gz > $STATS_DIR/${S}.stats
    TOTAL=$(grep "^SN" $STATS_DIR/${S}.stats | grep "number of records" | cut -f4)
    SNPS=$(grep  "^SN" $STATS_DIR/${S}.stats | grep "number of SNPs"    | cut -f4)
    INDELS=$(grep "^SN" $STATS_DIR/${S}.stats | grep "number of indels"  | cut -f4)
    TITV=$(grep  "^SN" $STATS_DIR/${S}.stats | grep "Ts/Tv ratio"        | cut -f4)
    echo "$S,$TOTAL,$SNPS,$INDELS,$TITV" >> $STATS_DIR/per_sample_stats.csv
    echo "Done: $S | SNPs=$SNPS Indels=$INDELS Ti/Tv=$TITV"
done

echo "" && echo "=== Joint VCF Stats ==="
bcftools stats $JOINT_DIR/all20_genotyped.vcf.gz > $STATS_DIR/joint_all.stats
grep "^SN" $STATS_DIR/joint_all.stats

echo "Stats saved to: $STATS_DIR/"
EOF

qsub /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/scripts/07_variant_stats.pbs
```

---

## Step 3: Visualisation (Python, run locally)

Copy `per_sample_stats.csv` from HPC to your laptop first:
```bash
scp e1520562@atlas9-c01.nus.edu.sg:/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/output/stats/per_sample_stats.csv .
```

Then run this Python script:

```python
# variant_analysis.py
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

df = pd.read_csv('per_sample_stats.csv')

# Population and colour mapping
pop_map = {
    'HG00096':'GBR','HG00097':'GBR','HG00099':'GBR','HG00100':'GBR',
    'NA12878':'CEU','NA12891':'CEU','NA12892':'CEU',
    'NA20502':'TSI','NA20510':'TSI','NA20518':'TSI','NA20525':'TSI',
    'NA19240':'YRI','HG02461':'GWD','HG03052':'MSL',
    'NA18534':'CHB','NA18939':'JPT',
    'HG03713':'ITU','HG03006':'BEB',
    'HG00553':'PUR','HG01112':'CLM'
}
superpop_map = {
    'GBR':'EUR','CEU':'EUR','TSI':'EUR',
    'YRI':'AFR','GWD':'AFR','MSL':'AFR',
    'CHB':'EAS','JPT':'EAS',
    'ITU':'SAS','BEB':'SAS',
    'PUR':'AMR','CLM':'AMR'
}
superpop_colors = {
    'EUR':'#023E8A','AFR':'#02C39A',
    'EAS':'#F9C74F','SAS':'#F47C5A','AMR':'#765ED4'
}
df['population'] = df['sample'].map(pop_map)
df['superpop']   = df['population'].map(superpop_map)
df['color']      = df['superpop'].map(superpop_colors)
df = df.sort_values('total_records', ascending=False)

# ── Figure 1: SNP + Indel counts per sample ───────────────────────────────────
fig, ax = plt.subplots(figsize=(14, 6))
ax.bar(range(len(df)), df['snps'],   color=df['color'], alpha=0.85, label='SNPs')
ax.bar(range(len(df)), df['indels'], color=df['color'], alpha=0.5,
       bottom=df['snps'], label='Indels')
ax.set_xticks(range(len(df)))
ax.set_xticklabels(df['sample'], rotation=45, ha='right', fontsize=9)
ax.set_ylabel('Variant Count', fontsize=12)
ax.set_title('SNP and Indel Counts per Sample\n(20 exome samples, 1000 Genomes)', fontsize=13)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v,_: f'{int(v):,}'))
from matplotlib.patches import Patch
ax.legend(handles=[Patch(facecolor=c, label=s) for s,c in superpop_colors.items()],
          title='Superpopulation', loc='upper right', fontsize=9)
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig('fig_variant_counts.png', dpi=150, bbox_inches='tight')
print("Saved: fig_variant_counts.png")

# ── Figure 2: Ti/Tv ratio per sample ─────────────────────────────────────────
fig, ax = plt.subplots(figsize=(14, 5))
ax.bar(range(len(df)), df['titv_ratio'], color=df['color'], alpha=0.85)
ax.axhline(y=2.8, color='red', linestyle='--', linewidth=1.5,
           label='Expected exome Ti/Tv (~2.8)')
ax.axhline(y=df['titv_ratio'].mean(), color='navy', linestyle=':',
           linewidth=1.5, label=f"Our mean ({df['titv_ratio'].mean():.2f})")
ax.set_xticks(range(len(df)))
ax.set_xticklabels(df['sample'], rotation=45, ha='right', fontsize=9)
ax.set_ylabel('Ti/Tv Ratio', fontsize=12)
ax.set_title('Ti/Tv Ratio per Sample\n(Expected ~2.8 for exome)', fontsize=13)
ax.legend(); ax.grid(axis='y', alpha=0.3); ax.set_ylim(0, 4)
plt.tight_layout()
plt.savefig('fig_titv_ratio.png', dpi=150, bbox_inches='tight')
print("Saved: fig_titv_ratio.png")

# ── Figure 3: By superpopulation ──────────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(12, 5))
df.groupby('superpop')[['snps','indels']].mean().plot(
    kind='bar', ax=axes[0], color=['#023E8A','#90E0EF'], edgecolor='white')
axes[0].set_title('Mean SNP & Indel Count\nby Superpopulation', fontsize=12)
axes[0].set_xlabel(''); axes[0].tick_params(axis='x', rotation=0)
axes[0].yaxis.set_major_formatter(mticker.FuncFormatter(lambda v,_: f'{int(v):,}'))

titv_by_pop = df.groupby('superpop')['titv_ratio'].mean()
titv_by_pop.plot(kind='bar', ax=axes[1],
    color=[superpop_colors[s] for s in titv_by_pop.index], edgecolor='white')
axes[1].axhline(y=2.8, color='red', linestyle='--', linewidth=1.5, label='Expected 2.8')
axes[1].set_title('Mean Ti/Tv Ratio\nby Superpopulation', fontsize=12)
axes[1].set_xlabel(''); axes[1].tick_params(axis='x', rotation=0)
axes[1].legend(); axes[1].set_ylim(0, 4)
plt.suptitle('Variant Statistics by Superpopulation', fontsize=13)
plt.tight_layout()
plt.savefig('fig_by_superpop.png', dpi=150, bbox_inches='tight')
print("Saved: fig_by_superpop.png")

# ── Print summary ─────────────────────────────────────────────────────────────
print(f"\n=== Summary ===")
print(f"Mean SNPs per sample:   {df['snps'].mean():,.0f}")
print(f"Mean Indels per sample: {df['indels'].mean():,.0f}")
print(f"Mean Ti/Tv:             {df['titv_ratio'].mean():.3f}  (expected: 2.800)")
print(f"\nTi/Tv by superpopulation:")
print(df.groupby('superpop')['titv_ratio'].mean().round(3).to_string())
```

---

## Expected Values (for validation)

| Metric | Expected (exome) | Action if off |
|--------|-----------------|---------------|
| Ti/Tv ratio | 2.6 – 3.0 | Flag pipeline issue if outside range |
| SNPs per sample | 50,000 – 150,000 | Normal variation across populations |
| Indels | ~10–15% of SNPs | Check filtering if very high/low |

---

## What to Send After Analysis

- **Member E (Writer):** mean Ti/Tv, total variants, validation statement
- **Member F (PPT):** `fig_variant_counts.png`, `fig_titv_ratio.png`, `fig_by_superpop.png`
- **Amanda (C):** per-sample stats CSV (for combined benchmark slides)
