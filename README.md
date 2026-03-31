# PHM5004 Group Project
## Option 1: Multi-sample Variant Calling Pipeline

**Karina

---

## Repository Structure

```
PHM5004_VariantCalling/
├── README.md
├── HANDOFF_TO_MEMBER_B.md     ← Nextflow templates + environment notes for Member B
└── scripts/
    ├── 00_initial_infrastructure.sh   ← Day 0: setup, migration, fai, dict
    ├── 01_prepare_reference.sh        ← Reference verification helper
    ├── 02_bwa_index.pbs               ← BWA 0.7.17 index (PBS job, ~2h)
    ├── 03_download_cram.pbs           ← Download 20 CRAM files (PBS job, ~6-8h)
    ├── 04_serial_pipeline.pbs         ← Serial baseline pipeline (PBS job, ~24-48h)
    └── 05_verify_downloads.sh         ← Check all CRAM files downloaded OK
```

---

## Pipeline Overview

```
Reference Prep       Data Acquisition       Serial Pipeline (Benchmark)
─────────────        ────────────────       ───────────────────────────
hg38.fa              20x CRAM (1000G)       CRAM → FASTQ
  └─ fai index    →    └─ HTTPS download  →   └─ BWA 0.7.17 align
  └─ BWA index                               └─ SAMtools sort/index
  └─ GATK dict                               └─ GATK MarkDuplicates
                                             └─ GATK HaplotypeCaller
                                             └─ timing log → Member C
```

---

## Scripts (run in order)

| # | Script | Purpose | Runtime | How |
|---|--------|---------|---------|-----|
| 0 | `00_initial_infrastructure.sh` | Setup dirs, migrate storage, fai index, GATK dict | ~5 min | `bash` |
| 1 | `01_prepare_reference.sh` | Re-verify reference files are complete | ~1 min | `bash` |
| 2 | `02_bwa_index.pbs` | Build BWA 0.7.17 index | ~2h | `qsub` |
| 3 | `03_download_cram.pbs` | Download 20 CRAM files via HTTPS | ~6-8h | `qsub` |
| 4 | `05_verify_downloads.sh` | Check all 20 CRAM files non-zero | ~1 min | `bash` |
| 5 | `04_serial_pipeline.pbs` | Run full serial pipeline (benchmark) | ~24-48h | `qsub` |

> Steps 2 and 3 can run simultaneously.

---

## NUS HPC Quick Reference

```bash
# Scheduler: PBS/Torque (NOT SLURM)
qsub script.pbs          # submit job
qstat -u e1520562        # check status (R=running, Q=queued)
qdel <jobid>             # cancel job

# Modules
module load samtools      # 1.9
module load bwa/0.7.17    # 0.7.17 (bwa-mem2 NOT available)
module load gatk          # 4.0.2.1
```

---

## Key Paths

| Resource | Path |
|----------|------|
| Project root | `/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/` |
| Reference genome | `.../reference/hg38.fa` |
| CRAM files | `.../cram/${SAMPLE_ID}.cram` |
| Serial output | `.../output/serial/` |
| Timing log | `.../logs/serial_timing.log` |

---

## Completed Jobs Log

| Job ID | Script | Status | Duration |
|--------|--------|--------|---------|
| 446823 | `02_bwa_index.pbs` | ✅ Done | 2h 9min |
| 446824 | (first download attempt) | ❌ Failed | FTP blocked |
| 446890 | `03_download_cram.pbs` | ✅ Done | ~6h |

---

## Known Issues & Fixes

| Issue | Fix |
|-------|-----|
| `samtools dict` → 0-byte file | Use `gatk CreateSequenceDictionary` with absolute paths |
| FTP port 21 blocked | Use HTTPS instead |
| bwa-mem2 crashes (missing CXXABI) | Use `bwa/0.7.17` module |
| Home quota full (20GB) | Project moved to `/hpctmp`, symlinked |
| 3 samples missing exome data | HG02922→HG02461, HG03642→HG03713, HG03871→HG03006 |
