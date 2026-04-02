# PHM5004 — Benchmark Data Handoff
## To: Amanda 
## From: Karina

---

## Serial Pipeline Results — Ready to Plot

All 20 samples completed successfully.
**Total serial wall-clock time: 59,100 seconds (16 hours 25 minutes)**

---

## Raw Timing Data (CSV format)

Save this as `serial_timing.csv`:

```
sample,population,superpop,cram_to_fastq_s,bwa_align_s,markdup_s,haplotypecaller_s,total_s,total_min
HG00096,GBR,EUR,9,41,21,2486,2557,42.6
HG00097,GBR,EUR,12,86,24,2663,2785,46.4
HG00099,GBR,EUR,16,113,29,2763,2932,48.9
HG00100,GBR,EUR,226,552,61,2728,3585,59.8
NA12878,CEU,EUR,90,364,41,2654,3163,52.7
NA12891,CEU,EUR,488,595,60,2702,3861,64.4
NA12892,CEU,EUR,38,113,28,2563,2748,45.8
NA19240,YRI,AFR,4,17,13,2483,2517,42.0
NA18534,CHB,EAS,17,105,27,2642,2792,46.5
NA18939,JPT,EAS,26,188,37,2735,2988,49.8
HG00553,PUR,AMR,21,186,31,2582,2822,47.0
HG01112,CLM,AMR,33,223,217,2810,3297,54.9
HG02461,GWD,AFR,13,60,22,2616,2712,45.2
HG03052,MSL,AFR,8,55,23,2499,2585,43.1
HG03713,ITU,SAS,13,55,21,2498,2587,43.1
HG03006,BEB,SAS,155,91,23,2604,2875,47.9
NA20502,TSI,EUR,27,207,34,3084,3354,55.9
NA20510,TSI,EUR,5,31,15,2811,2864,47.7
NA20518,TSI,EUR,14,128,27,2738,2908,48.5
NA20525,TSI,EUR,12,115,30,2850,3008,50.1
```

---

## Key Numbers for Slides

| Metric | Value |
|--------|-------|
| Total serial time | **59,100s (16h 25min)** |
| Mean per sample | **2,955s (49.3 min)** |
| Fastest sample | NA19240 — 2,517s (41:57) |
| Slowest sample | NA12891 — 3,861s (01:04:21) |
| HaplotypeCaller share | **53,712s = 90.9% of total** |
| BWA align share | 3,325s = 5.6% |
| CRAM→FASTQ share | 1,327s = 2.2% |
| MarkDuplicates share | 784s = 1.3% |

**Theoretical max speedup (20 parallel jobs): 20×**
**Expected parallel time (if perfect): ~2,955s (≈49 min)**

---

## Suggested Figures for the Presentation

### Figure 1 — Stacked Bar: Time breakdown per sample
```python
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

df = pd.read_csv('serial_timing.csv')
df = df.sort_values('total_s', ascending=True)

fig, ax = plt.subplots(figsize=(14, 7))

steps = ['cram_to_fastq_s', 'bwa_align_s', 'markdup_s', 'haplotypecaller_s']
colors = ['#90E0EF', '#00B4D8', '#0096C7', '#023E8A']
labels = ['CRAM→FASTQ', 'BWA Align', 'MarkDuplicates', 'HaplotypeCaller']

bottom = [0] * len(df)
for step, color, label in zip(steps, colors, labels):
    ax.barh(df['sample'], df[step], left=bottom,
            color=color, label=label, edgecolor='white', linewidth=0.5)
    bottom = [b + v for b, v in zip(bottom, df[step])]

ax.set_xlabel('Wall-clock Time (seconds)', fontsize=12)
ax.set_title('Serial Pipeline: Per-sample Time Breakdown\n(20 samples, NUS HPC, 1 CPU)', fontsize=13)
ax.legend(loc='lower right')
ax.axvline(x=sum(df['total_s'])/len(df), color='red',
           linestyle='--', linewidth=1.5, label='Mean')
ax.grid(axis='x', alpha=0.3)
plt.tight_layout()
plt.savefig('fig1_serial_breakdown.png', dpi=150, bbox_inches='tight')
plt.show()
print(f"Total serial time: {df['total_s'].sum():,}s ({df['total_s'].sum()/3600:.1f}h)")
```

---

### Figure 2 — Pie Chart: Step contribution to total runtime
```python
import matplotlib.pyplot as plt

steps = ['CRAM→FASTQ', 'BWA Align', 'MarkDuplicates', 'HaplotypeCaller']
times = [1327, 3325, 784, 53712]
colors = ['#90E0EF', '#00B4D8', '#0096C7', '#023E8A']
explode = [0, 0, 0, 0.05]

fig, ax = plt.subplots(figsize=(8, 6))
wedges, texts, autotexts = ax.pie(
    times, labels=steps, colors=colors,
    autopct='%1.1f%%', explode=explode,
    startangle=90, textprops={'fontsize': 11}
)
autotexts[3].set_fontweight('bold')
ax.set_title('Serial Pipeline: Runtime Composition\n(Total: 59,100s)', fontsize=13)
plt.tight_layout()
plt.savefig('fig2_runtime_pie.png', dpi=150, bbox_inches='tight')
plt.show()
```

---

### Figure 3 — Serial vs Parallel comparison bar (fill in Perry's number when ready)
```python
import matplotlib.pyplot as plt
import numpy as np

# Serial result (Member A)
serial_time = 59100   # seconds

# Parallel result — UPDATE THIS when Perry's pipeline completes
parallel_time = None  # e.g. 3200  ← fill in Perry's actual number

fig, ax = plt.subplots(figsize=(7, 5))

bars = ['Serial\n(1 process)', 'Parallel\n(20 processes)']
times = [serial_time, parallel_time if parallel_time else 0]
colors = ['#023E8A', '#02C39A']

b = ax.bar(bars, [t/3600 for t in times], color=colors,
           width=0.5, edgecolor='white')
ax.set_ylabel('Wall-clock Time (hours)', fontsize=12)
ax.set_title('Serial vs Parallel Pipeline\n(20 exome samples, NUS HPC)', fontsize=13)

# Annotate
ax.text(0, serial_time/3600 + 0.2,
        f'{serial_time:,}s\n({serial_time/3600:.1f}h)', ha='center', fontsize=10)

if parallel_time:
    speedup = serial_time / parallel_time
    ax.text(1, parallel_time/3600 + 0.2,
            f'{parallel_time:,}s\n({parallel_time/3600:.1f}h)', ha='center', fontsize=10)
    ax.set_title(
        f'Serial vs Parallel Pipeline\nSpeedup: {speedup:.1f}×', fontsize=13)

ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig('fig3_serial_vs_parallel.png', dpi=150, bbox_inches='tight')
plt.show()
```

---

### Figure 4 — Speedup curve with Amdahl's Law overlay
```python
import numpy as np
import matplotlib.pyplot as plt

serial_time = 59100

# Amdahl's Law: parallel fraction = HaplotypeCaller fraction
p = 53712 / 59100   # = 0.909 (parallelisable fraction)
s = 1 - p           # = 0.091 (serial fraction)

n_processors = np.array([1, 2, 4, 5, 10, 20])
amdahl_speedup = 1 / (s + p / n_processors)

# Actual data points — UPDATE when Perry provides numbers
# actual_n = [1, 20]
# actual_speedup = [1.0, serial_time / parallel_time]

fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(n_processors, amdahl_speedup, 'b--o',
        label="Amdahl's Law (p=90.9%)", linewidth=2, markersize=6)
ax.plot(n_processors, n_processors, 'gray', linestyle=':',
        label='Ideal linear speedup', linewidth=1.5)
# ax.scatter(actual_n, actual_speedup, color='#02C39A', s=120, zorder=5,
#            label='Actual (Perry)', marker='*')

ax.set_xlabel('Number of parallel processes', fontsize=12)
ax.set_ylabel('Speedup (×)', fontsize=12)
ax.set_title("Speedup vs Amdahl's Law Prediction\n(HaplotypeCaller = 90.9% parallelisable)", fontsize=12)
ax.legend()
ax.grid(alpha=0.3)
ax.set_xticks(n_processors)
plt.tight_layout()
plt.savefig('fig4_speedup_curve.png', dpi=150, bbox_inches='tight')
plt.show()

print(f"Amdahl predicted speedup at 20x: {amdahl_speedup[-1]:.2f}x")
print(f"Theoretical max speedup: {1/s:.2f}x")
```

---

## Notes for Amanda

1. **Figure 3 & 4 need Perry's parallel timing** — leave placeholders for now, fill in when his pipeline completes
2. **HaplotypeCaller = 90.9% of runtime** — this is your key talking point. It explains why parallelisation is so effective and directly answers the "justify your parallelisation strategy" rubric criterion
3. **Amdahl's Law max speedup = 1/(1-0.909) = 11.0×** — even with infinite processors, the serial fraction caps speedup. Mention this in the presentation
4. All timing data is in `/hpctmp/e1520562/PHM5004_Project/Option1_VariantCalling/logs/serial_timing.log` on NUS HPC if you need the raw file
