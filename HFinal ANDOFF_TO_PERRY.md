# PHM5004 — Infrastructure & Serial Baseline Handoff
## To: Perry 
## From: Karina

---

## ✅ What's Ready for You

| Resource | Status | Path |
|----------|--------|------|
| Reference genome (hg38) | ✅ Ready | `.../reference/hg38.fa` |
| BWA 0.7.17 index | ✅ Ready | `.../reference/hg38.fa.{amb,ann,pac,sa}` |
| GATK dict | ✅ Ready | `.../reference/hg38.dict` |
| samtools fai | ✅ Ready | `.../reference/hg38.fa.fai` |
| 20x CRAM files | ✅ Ready | `.../cram/${SAMPLE}.cram` |
| Serial GVCFs (your baseline) | ✅ Ready | `.../output/serial/gvcf/` |
| Serial timing log | ✅ Ready | `.../logs/serial_timing.log` |

**Serial total: 59,100s (16h 25min) — this is your benchmark to beat.**

---

## 🗂️ Full Path Reference

```
BASE = /hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling

Reference:     $BASE/reference/hg38.fa
CRAM input:    $BASE/cram/${SAMPLE}.cram
Serial GVCFs:  $BASE/output/serial/gvcf/${SAMPLE}.g.vcf.gz
Parallel out:  $BASE/output/parallel/gvcf/   ← your output goes here
Joint out:     $BASE/output/joint/            ← joint genotyping output
Logs:          $BASE/logs/
Tmp:           $BASE/tmp/
```

---

## 📋 Sample List (20 samples)

```
HG00096  HG00097  HG00099  HG00100   (GBR, EUR)
NA12878  NA12891  NA12892             (CEU, EUR)
NA20502  NA20510  NA20518  NA20525   (TSI, EUR)
NA19240                               (YRI, AFR)
HG02461  HG03052                     (GWD/MSL, AFR)
NA18534  NA18939                     (CHB/JPT, EAS)
HG03713  HG03006                     (ITU/BEB, SAS)
HG00553  HG01112                     (PUR/CLM, AMR)
```

> Note: HG02922→HG02461, HG03642→HG03713, HG03871→HG03006
> (originals had no exome data in 1000 Genomes)

---

## ⚠️ Critical HPC Environment Notes

### Scheduler: PBS/Torque (NOT SLURM)
```bash
qsub script.pbs          # NOT sbatch
qstat -u e1520562        # NOT squeue
qdel <jobid>             # NOT scancel
```

### Queue requirements
| Queue | Min CPUs | Notes |
|-------|----------|-------|
| `serial` | 1 | Max 8GB mem — too small for pipeline |
| `parallel` | **12** | Use this — min 12 CPUs required |

### Modules
```bash
module load samtools          # 1.9
module load bwa/0.7.17        # ⚠️ bwa-mem2 NOT available
module load gatk              # 4.0.2.1
```

### ⚠️ bwa-mem2 is NOT available
The HPC system libstdc++ is too old (missing CXXABI_1.3.8).
**Use `bwa/0.7.17` in all Nextflow processes.**
BWA 0.7.17 index files are already built at `.../reference/hg38.fa.*`

### ⚠️ GATK syntax quirks (4.0.2.1)
```bash
# Use --TMP_DIR (capital) NOT --tmp-dir
gatk HaplotypeCaller --TMP_DIR $BASE/tmp ...   # ✅
gatk HaplotypeCaller --tmp-dir $BASE/tmp ...   # ❌ not recognised
```

---

## 🔧 Nextflow Process Templates (copy-paste ready)

### nextflow.config
```groovy
process {
    executor = 'pbspro'
    queue    = 'parallel'

    withName: 'CRAM_TO_FASTQ' {
        cpus   = 12
        memory = '8 GB'
        time   = '2h'
    }
    withName: 'BWA_ALIGN' {
        cpus   = 12
        memory = '24 GB'
        time   = '4h'
    }
    withName: 'MARK_DUPLICATES' {
        cpus   = 12
        memory = '24 GB'
        time   = '2h'
    }
    withName: 'HAPLOTYPE_CALLER' {
        cpus   = 12
        memory = '24 GB'
        time   = '4h'
    }
    withName: 'JOINT_GENOTYPING' {
        cpus   = 12
        memory = '48 GB'
        time   = '6h'
    }
}

params {
    base    = '/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling'
    ref     = "${params.base}/reference/hg38.fa"
    cramdir = "${params.base}/cram"
    outdir  = "${params.base}/output/parallel"
    tmpdir  = "${params.base}/tmp"
}
```

### Process 1: CRAM → FASTQ
```groovy
process CRAM_TO_FASTQ {
    tag "$sample_id"
    cpus 12

    input:
    tuple val(sample_id), path(cram), path(crai)

    output:
    tuple val(sample_id), path("${sample_id}_R1.fq.gz"), path("${sample_id}_R2.fq.gz")

    script:
    """
    module load samtools
    samtools fastq -@ ${task.cpus} -n \\
        -1 ${sample_id}_R1.fq.gz \\
        -2 ${sample_id}_R2.fq.gz \\
        -0 /dev/null -s /dev/null \\
        --reference ${params.ref} \\
        ${cram}
    """
}
```

### Process 2: BWA Alignment
```groovy
process BWA_ALIGN {
    tag "$sample_id"
    cpus 12

    input:
    tuple val(sample_id), path(r1), path(r2)

    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam"), path("${sample_id}.sorted.bam.bai")

    script:
    """
    module load bwa/0.7.17
    module load samtools
    bwa mem -t ${task.cpus} \\
        -R "@RG\\tID:${sample_id}\\tSM:${sample_id}\\tPL:ILLUMINA\\tLB:lib1\\tPU:unit1" \\
        ${params.ref} ${r1} ${r2} \\
        | samtools sort -@ ${task.cpus} -o ${sample_id}.sorted.bam
    samtools index ${sample_id}.sorted.bam
    """
}
```

### Process 3: MarkDuplicates
```groovy
process MARK_DUPLICATES {
    tag "$sample_id"
    cpus 12

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    tuple val(sample_id), path("${sample_id}.markdup.bam"), path("${sample_id}.markdup.bam.bai")

    script:
    """
    module load gatk
    module load samtools
    gatk MarkDuplicates \\
        -I ${bam} \\
        -O ${sample_id}.markdup.bam \\
        -M ${sample_id}.markdup.metrics \\
        --REMOVE_DUPLICATES false \\
        --TMP_DIR ${params.tmpdir}
    samtools index ${sample_id}.markdup.bam
    """
}
```

### Process 4: HaplotypeCaller (GVCF)
```groovy
process HAPLOTYPE_CALLER {
    tag "$sample_id"
    cpus 12
    publishDir "${params.outdir}/gvcf", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    tuple val(sample_id), path("${sample_id}.g.vcf.gz"), path("${sample_id}.g.vcf.gz.tbi")

    script:
    """
    module load gatk
    gatk HaplotypeCaller \\
        -R ${params.ref} \\
        -I ${bam} \\
        -O ${sample_id}.g.vcf.gz \\
        -ERC GVCF \\
        --TMP_DIR ${params.tmpdir}
    """
}
```

### Main workflow (parallel across all 20 samples)
```groovy
workflow {
    // Create channel from sample list
    Channel
        .fromPath("${params.cramdir}/*.cram")
        .map { cram ->
            def sample_id = cram.baseName.replaceAll('.cram', '')
            def crai = file("${params.cramdir}/${sample_id}.cram.crai")
            tuple(sample_id, cram, crai)
        }
        .set { cram_ch }

    // Run pipeline — all 20 samples in parallel
    CRAM_TO_FASTQ(cram_ch)
    BWA_ALIGN(CRAM_TO_FASTQ.out)
    MARK_DUPLICATES(BWA_ALIGN.out)
    HAPLOTYPE_CALLER(MARK_DUPLICATES.out)
}
```

### Submit Nextflow job
```bash
#!/bin/bash
#PBS -N nextflow_parallel
#PBS -q parallel
#PBS -l walltime=24:00:00
#PBS -l mem=24gb
#PBS -l ncpus=12

module load java

nextflow run main.nf \
    -c nextflow.config \
    -with-report logs/nextflow_report.html \
    -with-timeline logs/nextflow_timeline.html \
    -resume
```

---

## 📊 Benchmark Context

Serial timing for each step (use to estimate your parallel speedup):

| Step | Serial total (20 samples) | % of runtime |
|------|--------------------------|--------------|
| CRAM→FASTQ | 1,327s | 2.2% |
| BWA align | 3,325s | 5.6% |
| MarkDuplicates | 784s | 1.3% |
| **HaplotypeCaller** | **53,712s** | **90.9%** |
| **TOTAL** | **59,100s (16h 25min)** | 100% |

**Target:** Complete all 20 samples in <4 hours (>4× speedup)
**Amdahl's Law max:** 1/(1-0.909) = **11.0× theoretical maximum**

After your parallel run completes, send Amanda:
- Total parallel wall-clock time
- Per-sample timing if available
- `nextflow_timeline.html` (great for slides)

---

## 🔍 Validating Your Output

Compare your GVCFs against the serial baseline:
```bash
# Check variant counts match
for SAMPLE in HG00096 NA12878 NA19240; do
    SERIAL=$(bcftools stats output/serial/gvcf/${SAMPLE}.g.vcf.gz | grep "number of records" | cut -f4)
    PARALLEL=$(bcftools stats output/parallel/gvcf/${SAMPLE}.g.vcf.gz | grep "number of records" | cut -f4)
    echo "$SAMPLE — Serial: $SERIAL  Parallel: $PARALLEL"
done
```
