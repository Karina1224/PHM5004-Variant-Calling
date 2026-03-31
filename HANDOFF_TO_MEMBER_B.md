# PHM5004 Variant Calling
> **Maintainer:** Karina 
> **Handoff target:** Perry
> **Last updated:** 2026-03-31
---

## 1. Storage & Paths

`/home` has only a 20GB quota. The entire project has been migrated to `/hpctmp`.
**Use these absolute paths in all Nextflow scripts:**

| Resource | Path |
|----------|------|
| Project root | `/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/` |
| Reference genome | `.../reference/hg38.fa` |
| BWA index (prefix) | `.../reference/hg38.fa` |
| GATK dict | `.../reference/hg38.dict` |
| samtools fai | `.../reference/hg38.fa.fai` |
| CRAM files | `.../cram/${SAMPLE_ID}.cram` |
| Serial GVCF output | `.../output/serial/gvcf/` |
| Parallel GVCF output | `.../output/parallel/gvcf/` ← Member B writes here |
| Joint genotyping output | `.../output/joint/` |
| Logs | `.../logs/` |
| Conda env | `source /home/svu/e1520562/miniconda3/bin/activate variant_calling` |

---

## 2. Infrastructure Status Checklist

- [x] Storage migrated from `/home` to `/hpctmp` (symlink kept at `~/PHM5004_Project`)
- [x] `hg38.fa` reference genome in place (3.1GB, GRCh38)
- [x] `hg38.fa.fai` samtools index built
- [x] `hg38.dict` GATK sequence dictionary built (69KB)
- [x] `hg38.fa.amb / .ann / .pac / .sa` BWA 0.7.17 index built (Job 446823, ~2h)
- [x] 20 CRAM files downloaded to `cram/` (Job 446890, ~100GB total)
- [x] Serial pipeline script ready (`04_serial_pipeline.pbs`)
- [ ] Serial pipeline executed on all 20 samples ← **next step**
- [ ] Timing data handed to Member C ← **after serial run**

---

## 3. Critical HPC Environment Notes for Member B

### Scheduler: PBS/Torque (NOT SLURM)
```bash
qsub script.pbs        # submit  (NOT sbatch)
qstat -u e1520562      # status  (NOT squeue)
qdel <jobid>           # cancel  (NOT scancel)
```

### Available queues
| Queue | Use for |
|-------|---------|
| `serial` | Single-core jobs (index building, downloads) |
| `parallel` | Multi-core jobs (alignment, variant calling) |

### Module loading
```bash
module load samtools          # version 1.9
module load bwa/0.7.17        # version 0.7.17
module load gatk              # version 4.0.2.1 (default)
```

### ⚠️ BWA-MEM2 is NOT available on NUS HPC
BWA-MEM2 was attempted but fails with:
```
/lib64/libstdc++.so.6: version 'CXXABI_1.3.8' not found
/lib64/libstdc++.so.6: version 'GLIBCXX_3.4.21' not found
```
**Use `bwa/0.7.17` in all scripts.** The reference index files (`.amb`, `.ann`,
`.pac`, `.sa`) are already built for BWA 0.7.17.

---

## 4. Sample Manifest (20 samples)

| Sample ID | Population | Superpop | CRAM filename |
|-----------|-----------|---------|--------------|
| HG00096 | GBR | EUR | HG00096.cram |
| HG00097 | GBR | EUR | HG00097.cram |
| HG00099 | GBR | EUR | HG00099.cram |
| HG00100 | GBR | EUR | HG00100.cram |
| NA12878 | CEU | EUR | NA12878.cram |
| NA12891 | CEU | EUR | NA12891.cram |
| NA12892 | CEU | EUR | NA12892.cram |
| NA19240 | YRI | AFR | NA19240.cram |
| NA18534 | CHB | EAS | NA18534.cram |
| NA18939 | JPT | EAS | NA18939.cram |
| HG00553 | PUR | AMR | HG00553.cram |
| HG01112 | CLM | AMR | HG01112.cram |
| HG02461 | GWD | AFR | HG02461.cram |
| HG03052 | MSL | AFR | HG03052.cram |
| HG03713 | ITU | SAS | HG03713.cram |
| HG03006 | BEB | SAS | HG03006.cram |
| NA20502 | TSI | EUR | NA20502.cram |
| NA20510 | TSI | EUR | NA20510.cram |
| NA20518 | TSI | EUR | NA20518.cram |
| NA20525 | TSI | EUR | NA20525.cram |

> **Note:** HG02922, HG03642, HG03871 had no exome data in the 1000 Genomes
> repository and were replaced with HG02461, HG03713, HG03006 from the same
> populations (GWD, ITU, BEB respectively).

---

## 5. Core Process Templates for Nextflow

Copy these into your Nextflow DSL2 processes directly.

### Process 1: CRAM → FASTQ
```bash
# IMPORTANT: --reference flag is required for CRAM decoding
# CRAM files are stored as diffs against the reference — without this flag,
# samtools cannot decode them correctly
samtools fastq -@ ${task.cpus} -n \
    -1 ${sample_id}_R1.fastq.gz \
    -2 ${sample_id}_R2.fastq.gz \
    -0 /dev/null -s /dev/null \
    --reference /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/reference/hg38.fa \
    ${sample_id}.cram
```

### Process 2: BWA Alignment
```bash
# Use bwa/0.7.17 — NOT bwa-mem2 (unavailable on NUS HPC)
# -R read group tag is required by GATK downstream
bwa mem -t ${task.cpus} \
    -R "@RG\tID:${sample_id}\tSM:${sample_id}\tPL:ILLUMINA\tLB:lib1\tPU:unit1" \
    /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/reference/hg38.fa \
    ${sample_id}_R1.fastq.gz \
    ${sample_id}_R2.fastq.gz \
    | samtools sort -@ ${task.cpus} -o ${sample_id}.sorted.bam
```

### Process 3: Mark Duplicates
```bash
# Use full absolute path for --TMP_DIR to avoid filling /tmp on compute node
gatk MarkDuplicates \
    -I ${sample_id}.sorted.bam \
    -O ${sample_id}.markdup.bam \
    -M ${sample_id}.markdup.metrics \
    --REMOVE_DUPLICATES false \
    --TMP_DIR /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/tmp
samtools index ${sample_id}.markdup.bam
```

### Process 4: HaplotypeCaller (GVCF mode)
```bash
# -ERC GVCF is required for joint genotyping across all 20 samples later
gatk HaplotypeCaller \
    -R /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/reference/hg38.fa \
    -I ${sample_id}.markdup.bam \
    -O ${sample_id}.g.vcf.gz \
    -ERC GVCF \
    --tmp-dir /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/tmp
```

---

## 6. Recommended Nextflow PBS Config

```groovy
// nextflow.config
process {
    executor = 'pbspro'
    queue    = 'parallel'

    withName: 'ALIGN' {
        cpus   = 8
        memory = '16 GB'
        time   = '4h'
    }
    withName: 'HAPLOTYPE_CALLER' {
        cpus   = 4
        memory = '16 GB'
        time   = '6h'
    }
    withName: 'MARK_DUPLICATES' {
        cpus   = 2
        memory = '8 GB'
        time   = '2h'
    }
}

params {
    base    = '/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling'
    ref     = "${params.base}/reference/hg38.fa"
    cram    = "${params.base}/cram"
    outdir  = "${params.base}/output/parallel"
}
```

---

## 7. Benchmark Data (for Amanda)

After the serial pipeline completes, timing data will be at:
```
/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/logs/serial_timing.log
```

Format (per sample + total):
```
>>> [NA12878] Start: ...
  Step 1 done: Xs   ← CRAM→FASTQ
  Step 2 done: Xs   ← BWA align
  Step 4 done: Xs   ← MarkDuplicates
  Step 5 done: Xs   ← HaplotypeCaller
  >>> [NA12878] TOTAL: Xs (HH:MM:SS)
...
TOTAL SERIAL TIME: Xs (HH:MM:SS)
```

Member B should produce an equivalent `parallel_timing.log` for comparison.

---

## 8. Troubleshooting Log

| Issue | Cause | Fix |
|-------|-------|-----|
| `samtools dict` produces 0-byte file | Known bug in samtools 1.9 on NUS HPC | Use `gatk CreateSequenceDictionary` instead |
| GATK dict: "File not found" error | Relative paths fail in GATK 4.0.2.1 | Use full absolute paths for `-R` and `-O` |
| GATK dict: "already exists" error | Old 0-byte .dict file present | `rm hg38.dict` then re-run |
| FTP download times out | NUS HPC blocks port 21 | Use HTTPS: `https://ftp.1000genomes.ebi.ac.uk/...` |
| CRAM filename 404 | Actual format differs from docs | Format: `{ID}.alt_bwamem_GRCh38DH.20150826.{POP}.exome.cram` |
| bwa-mem2 crashes | HPC libstdc++ too old (missing CXXABI_1.3.8) | Use `bwa/0.7.17` module instead |
| `qsub: Job violates resource limits` | Requested too much memory/time | Serial queue max: ~8GB, 1 CPU, 48h |
| Home directory full | 20GB quota exceeded by index files | Use `/hpctmp` for all large files |
