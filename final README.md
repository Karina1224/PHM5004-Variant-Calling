# PHM5004 Group Project — Option 1: Multi-sample Variant Calling Pipeline
## Member A: Infrastructure & Serial Baseline
**NUS HPC (PBS/Torque) | GRCh38 | 20 samples | 1000 Genomes Project**
**Deadline: Sat 11 Apr 2026**

---

## ✅ Completion Status

| Task | Status | Details |
|------|--------|---------|
| Reference genome (hg38) | ✅ Done | 3.1GB, GRCh38 |
| samtools fai index | ✅ Done | hg38.fa.fai |
| GATK sequence dictionary | ✅ Done | hg38.dict (69KB) |
| BWA 0.7.17 index | ✅ Done | Job 446823, 2h 9min |
| 20x CRAM download | ✅ Done | Job 446890, ~100GB |
| CRAM integrity check | ✅ Done | All 20 samples pass quickcheck |
| Serial pipeline (20 samples) | ✅ Done | **16h 25min total** |
| 20x GVCF output | ✅ Done | 528MB total |

---

## 📊 Serial Benchmark Results (Handed to Member C)

**Total serial wall-clock time: 59,100s (16h 25min)**

| Sample | Pop | CRAM→FASTQ | BWA align | MarkDup | HaplotypeCaller | **Total** |
|--------|-----|-----------|-----------|---------|-----------------|-----------|
| HG00096 | GBR | 9s | 41s | 21s | 2486s | **2557s (42:37)** |
| HG00097 | GBR | 12s | 86s | 24s | 2663s | **2785s (46:25)** |
| HG00099 | GBR | 16s | 113s | 29s | 2763s | **2932s (48:52)** |
| HG00100 | GBR | 226s | 552s | 61s | 2728s | **3585s (59:45)** |
| NA12878 | CEU | 90s | 364s | 41s | 2654s | **3163s (52:43)** |
| NA12891 | CEU | 488s | 595s | 60s | 2702s | **3861s (01:04:21)** |
| NA12892 | CEU | 38s | 113s | 28s | 2563s | **2748s (45:48)** |
| NA19240 | YRI | 4s | 17s | 13s | 2483s | **2517s (41:57)** |
| NA18534 | CHB | 17s | 105s | 27s | 2642s | **2792s (46:32)** |
| NA18939 | JPT | 26s | 188s | 37s | 2735s | **2988s (49:48)** |
| HG00553 | PUR | 21s | 186s | 31s | 2582s | **2822s (47:02)** |
| HG01112 | CLM | 33s | 223s | 217s | 2810s | **3297s (54:57)** |
| HG02461 | GWD | 13s | 60s | 22s | 2616s | **2712s (45:12)** |
| HG03052 | MSL | 8s | 55s | 23s | 2499s | **2585s (43:05)** |
| HG03713 | ITU | 13s | 55s | 21s | 2498s | **2587s (43:07)** |
| HG03006 | BEB | 155s | 91s | 23s | 2604s | **2875s (47:55)** |
| NA20502 | TSI | 27s | 207s | 34s | 3084s | **3354s (55:54)** |
| NA20510 | TSI | 5s | 31s | 15s | 2811s | **2864s (47:44)** |
| NA20518 | TSI | 14s | 128s | 27s | 2738s | **2908s (48:28)** |
| NA20525 | TSI | 12s | 115s | 30s | 2850s | **3008s (50:08)** |
| **TOTAL** | | **1327s** | **3325s** | **784s** | **53712s** | **59,100s (16:25:00)** |

**HaplotypeCaller dominates: 90.9% of total runtime → primary parallelisation target**

---

## 📁 Repository Structure

```
PHM5004_VariantCalling/
├── README.md
├── HANDOFF_TO_MEMBER_B.md        ← Nextflow templates for Perry
├── HANDOFF_TO_MEMBER_C.md        ← Benchmark data for Amanda
└── scripts/
    ├── 00_initial_infrastructure.sh   ← Day 0 setup
    ├── 01_prepare_reference.sh        ← Reference verification
    ├── 02_bwa_index.pbs               ← BWA index (qsub)
    ├── 03_download_cram.pbs           ← Download 20 CRAMs (qsub)
    ├── 04_serial_pipeline.pbs         ← Serial baseline (qsub)
    └── 05_verify_downloads.sh         ← Integrity check
```

---

## 🗂️ Key Paths on NUS HPC

| Resource | Path |
|----------|------|
| Project root | `/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/` |
| Reference | `.../reference/hg38.fa` |
| CRAM files | `.../cram/${SAMPLE_ID}.cram` |
| Serial GVCFs | `.../output/serial/gvcf/${SAMPLE_ID}.g.vcf.gz` |
| Timing log | `.../logs/serial_timing.log` |

---

## 🔧 NUS HPC Quick Reference

```bash
# Scheduler: PBS/Torque (NOT SLURM)
qsub script.pbs          # submit
qstat -u e1520562        # status (R=running, Q=queued)
qdel <jobid>             # cancel

# Modules
module load samtools      # 1.9
module load bwa/0.7.17    # bwa-mem2 NOT available (libstdc++ too old)
module load gatk          # 4.0.2.1

# Queues
# serial:   1 CPU, max 8GB, single-core jobs
# parallel: min 12 CPUs, min 2GB, used for pipeline jobs
```

---

## ⚠️ Lessons Learned / Troubleshooting

| Issue | Fix |
|-------|-----|
| `samtools dict` → 0-byte file | Use `gatk CreateSequenceDictionary` with **absolute paths** |
| GATK "File not found" on dict | Delete existing 0-byte .dict first, use full absolute paths |
| GATK `--tmp-dir` not recognised | Use `--TMP_DIR` (capital, GATK 4.0.2.1 syntax) |
| FTP port 21 blocked | Use HTTPS: `https://ftp.1000genomes.ebi.ac.uk/...` |
| CRAM filename format wrong | Actual: `{ID}.alt_bwamem_GRCh38DH.20150826.{POP}.exome.cram` |
| bwa-mem2 crashes | Missing CXXABI_1.3.8 — use `bwa/0.7.17` instead |
| Home quota full (20GB) | Moved project to `/hpctmp`, created symlink |
| serial queue mem exceeded | Use `parallel` queue: min 12 CPUs, set `mem=24gb` |
| 3 samples missing exome data | HG02922→HG02461, HG03642→HG03713, HG03871→HG03006 |
| 12 CRAM files corrupted | Re-downloaded with forced overwrite (no `-c` flag) |

---

## 📋 Completed Job Log

| Job ID | Script | Queue | Status | Wall Time |
|--------|--------|-------|--------|-----------|
| 446823 | bwa_index.pbs | serial | ✅ Exit 0 | 2h 9min |
| 446824 | download_cram.pbs | serial | ❌ FTP blocked | — |
| 446890 | download_cram2.pbs | serial | ✅ Exit 0 | 12h 44min |
| 447144 | fix_downloads.pbs | serial | ❌ Killed (2min) | — |
| 447145 | fix_downloads2.pbs | serial | ✅ Exit 0 | 4h 58min |
| 447275 | serial_test_1sample.pbs | serial | ❌ OOM killed | — |
| 447311 | serial_test_1sample.pbs | parallel | ✅ Exit 0 | 51min |
| 447XXX | serial_pipeline.pbs | parallel | ✅ Exit 0 | 16h 25min |
