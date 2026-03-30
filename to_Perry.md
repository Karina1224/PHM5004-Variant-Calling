# 给 Perry 的 Nextflow 交接文档
---

## 1. 运行环境与参考文件路径
写代码时请直接调用以下绝对路径（已开放权限）：

**Conda 环境激活命令:**
```bash
source /home/svu/e1520562/miniconda3/bin/activate variant_calling
```

**参考基因组 (含 BWA 索引):**
```text
/home/svu/e1520562/PHM5004_Project/Option1_VariantCalling/reference/hg38.fa
```

---

## 2. 核心转换与比对命令

### 第一步：CRAM 转 FASTQ
注意：必须用我提供的本地 reference 进行离线转换，并过滤单端 reads。

```bash
samtools fastq -@ 8 -n \
  -1 ${ID}_1.fastq.gz -2 ${ID}_2.fastq.gz \
  -0 /dev/null -s /dev/null \
  --reference /home/svu/e1520562/PHM5004_Project/Option1_VariantCalling/reference/hg38.fa \
  ${ID}.GRCh38DH.exome.cram
```

### 第二步：BWA-MEM2 比对

```bash
bwa-mem2 mem -t 8 \
  -R "@RG\tID:${ID}\tSM:${ID}\tPL:ILLUMINA" \
  /home/svu/e1520562/PHM5004_Project/Option1_VariantCalling/reference/hg38.fa \
  ${ID}_1.fastq.gz ${ID}_2.fastq.gz > ${ID}.sam
```

---

## 3. 最终确认的 20 样本下载链接

可以直接用 wget 或 Nextflow 批量拉取：

```text
# CEU / YRI 
ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/data/CEU/NA12878/exome_alignment/NA12878.GRCh38DH.exome.cram
ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/data/CEU/NA12891/exome_alignment/NA12891.GRCh38DH.exome.cram
ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/data/CEU/NA12892/exome_alignment/NA12892.GRCh38DH.exome.cram
ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/data/YRI/NA19240/exome_alignment/NA19240.GRCh38DH.exome.
