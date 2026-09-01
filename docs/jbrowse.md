# JBrowse

```bash
docker compose exec breedbase bash
cd /data/breedbase/genomes
```

## Reference Genome

```bash
samtools faidx reference.fasta
```

## Annotations

```bash
gt gff3 -sortlines -tidy annotations.gff > annotations.sorted.gff
mv annotations.sorted.gff annotations.gff
bgzip annotations.gff
tabix --csi -p gff annotations.gff.gz
```

## Variants

```bash
bgzip variants.vcf
tabix -p vcf --csi variants.vcf.gz
```

Filtering on SNP ID

```bash
bcftools view --include ID==@snps.txt variants.vcf.gz | cut -f 1-4
```

## GWAS

Convert to 0-based coordinates, convert P value to neg_log transform.

```bash
csvtk cut -t -f CHR,BP,SNP,A1,A2,P,BETA,SE,MAF,Z,fdr gwas_sumstat.txt \
  | csvtk rename -t -f CHR,BP,SNP,A1,A2,P,BETA,SE,MAF,Z,fdr -n 'chrom,pos,rsid,ref,alt,pvalue,beta,stderr_beta,alt_allele_freq,z_score,fdr'  \
  | csvtk mutate2 -t -n neg_log_pvalue -e '$pvalue' \
  | sed 's/^chrom/#chrom/g' \
  | awk -F '\t' 'BEGIN{OFS=FS}{if (NR > 1){$1="scaffold_"$1; $2=$2-1; $12 = -log($6)/log(10);}; print $0}' \
  > gwas.tsv
bgzip -f gwas.tsv
tabix --csi -0 -b 2 -s 1 -e 2 -f gwas.tsv.gz
```

## Config

> Outside container

`data/jbrowse/config.json`
