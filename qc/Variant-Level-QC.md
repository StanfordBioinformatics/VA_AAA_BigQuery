<!-- R Markdown Documentation, DO NOT EDIT THE PLAIN MARKDOWN VERSION OF THIS FILE -->

<!-- Copyright 2015 Google Inc. All rights reserved. -->

<!-- Licensed under the Apache License, Version 2.0 (the "License"); -->
<!-- you may not use this file except in compliance with the License. -->
<!-- You may obtain a copy of the License at -->

<!--     http://www.apache.org/licenses/LICENSE-2.0 -->

<!-- Unless required by applicable law or agreed to in writing, software -->
<!-- distributed under the License is distributed on an "AS IS" BASIS, -->
<!-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. -->
<!-- See the License for the specific language governing permissions and -->
<!-- limitations under the License. -->

# Part 4: Variant-Level QC





In Part 4 of the codelab, we perform some quality control analyses that could help to identify any problematic variants which should be excluded from further analysis.  The appropriate cut off thresholds will depend upon the input dataset and/or other factors.

* [Ti/Tv by Genomic Window](#titv-by-genomic-window)
* [Ti/Tv by Alternate Allele Counts](#titv-by-alternate-allele-counts)
* [Missingness Rate](#missingness-rate)
* [Hardy-Weinberg Equilibrium](#hardy-weinberg-equilibrium)
* [Heterozygous Haplotype](#heterozygous-haplotype)

By default this codelab runs upon the Illumina Platinum Genomes Variants. Update the table and change the source of sample information here if you wish to run the queries against a different dataset.

```r
tableReplacement <- list("_THE_TABLE_"="va_aaa_pilot_data.5_genome_test_gvcfs_no_calls",
                          "_THE_EXPANDED_TABLE_"="va_aaa_pilot_data.5_genome_test_vcfs_no_calls")
sampleData <- read.csv("http://storage.googleapis.com/genomics-public-data/platinum-genomes/other/platinum_genomes_sample_info.csv")
sampleInfo <- select(sampleData, call_call_set_name=Catalog.ID, gender=Gender)
```

## Ti/Tv by Genomic Window

Check whether the ratio of transitions vs. transversions in SNPs appears to be reasonable in each window of genomic positions.  This query may help identify problematic regions.


```r
result <- DisplayAndDispatchQuery("./sql/ti-tv-ratio.sql",
                                  project=project,
                                  replacements=c(tableReplacement,
                                                 "#_WHERE_"="WHERE reference_name='chr1'",
                                                 "_WINDOW_SIZE_"="100000"))
```

```
# Compute the Ti/Tv ratio for variants within genomic region windows.
SELECT
  reference_name,
  window * 100000 AS window_start,
  transitions,
  transversions,
  transitions/transversions AS titv,
  num_variants_in_window,
FROM (
  SELECT
    reference_name,
    window,
    SUM(mutation IN ('A->G', 'G->A', 'C->T', 'T->C')) AS transitions,
    SUM(mutation IN ('A->C', 'C->A', 'G->T', 'T->G',
                     'A->T', 'T->A', 'C->G', 'G->C')) AS transversions,
    COUNT(mutation) AS num_variants_in_window
  FROM (
    SELECT
      reference_name,
      INTEGER(FLOOR(start / 100000)) AS window,
      CONCAT(reference_bases, CONCAT(STRING('->'), alternate_bases)) AS mutation,
      COUNT(alternate_bases) WITHIN RECORD AS num_alts,
    FROM
      [va_aaa_pilot_data.5_genome_test_gvcfs_no_calls]
    # Optionally add clause here to limit the query to a particular
    # region of the genome.
    WHERE reference_name='chr1'
    HAVING
      # Skip 1/2 genotypes _and non-SNP variants
      num_alts = 1
      AND reference_bases IN ('A','C','G','T')
      AND alternate_bases IN ('A','C','G','T'))
  GROUP BY
    reference_name,
    window)
ORDER BY
  window_start
```
Number of rows returned by this query: 2278.

Displaying the first few results:
<!-- html table generated in R 3.1.2 by xtable 1.7-4 package -->
<!-- Fri Mar 13 09:09:34 2015 -->
<table border=1>
<tr> <th> reference_name </th> <th> window_start </th> <th> transitions </th> <th> transversions </th> <th> titv </th> <th> num_variants_in_window </th>  </tr>
  <tr> <td> chr1 </td> <td align="right">   0 </td> <td align="right">  85 </td> <td align="right">  66 </td> <td align="right"> 1.29 </td> <td align="right"> 151 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 100000 </td> <td align="right">  38 </td> <td align="right">  20 </td> <td align="right"> 1.90 </td> <td align="right">  58 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 200000 </td> <td align="right">  19 </td> <td align="right">  13 </td> <td align="right"> 1.46 </td> <td align="right">  32 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 300000 </td> <td align="right">   1 </td> <td align="right">   5 </td> <td align="right"> 0.20 </td> <td align="right">   6 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 400000 </td> <td align="right">   5 </td> <td align="right">   2 </td> <td align="right"> 2.50 </td> <td align="right">   7 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 500000 </td> <td align="right">  41 </td> <td align="right">  12 </td> <td align="right"> 3.42 </td> <td align="right">  53 </td> </tr>
   </table>

Visualizing the results:

```r
ggplot(result) +
  geom_point(aes(x=window_start, y=titv)) +
  xlab("Genomic Position") +
  ylab("Ti/Tv") +
  ggtitle("Ti/Tv by 100,000 base pair windows on Chromosome 1")
```

<img src="figure/titvByWindow-1.png" title="plot of chunk titvByWindow" alt="plot of chunk titvByWindow" style="display: block; margin: auto;" />

## Ti/Tv by Alternate Allele Counts

Check whether the ratio of transitions vs. transversions in SNPs appears to be resonable across the range of rare variants to common variants.  This query may help to identify problems with rare or common variants.


```r
result <- DisplayAndDispatchQuery("./sql/ti-tv-by-alternate-allele-count.sql",
                                  project=project,
                                  replacements=c(tableReplacement))
```

```
# Compute the Ti/Tv ratio for variants binned by alternate allele count.
SELECT
  transitions,
  transversions,
  transitions/transversions AS titv,
  alternate_allele_count
FROM (
  SELECT
    SUM(mutation IN ('A->G', 'G->A', 'C->T', 'T->C')) AS transitions,
    SUM(mutation IN ('A->C', 'C->A', 'G->T', 'T->G',
                     'A->T', 'T->A', 'C->G', 'G->C')) AS transversions,
    alternate_allele_count
  FROM (
    SELECT
      CONCAT(reference_bases, CONCAT(STRING('->'), alternate_bases)) AS mutation,
      COUNT(alternate_bases) WITHIN RECORD AS num_alts,
      SUM(call.genotype = 1) WITHIN RECORD AS alternate_allele_count,
    FROM
      [va_aaa_pilot_data.5_genome_test_gvcfs_no_calls]
    # Optionally add clause here to limit the query to a particular
    # region of the genome.
    #_WHERE_
    HAVING
      # Skip 1/2 genotypes _and non-SNP variants
      num_alts = 1
      AND reference_bases IN ('A','C','G','T')
      AND alternate_bases IN ('A','C','G','T'))
  GROUP BY
    alternate_allele_count)
ORDER BY
  alternate_allele_count DESC
```
Number of rows returned by this query: 11.

Displaying the first few results:
<!-- html table generated in R 3.1.2 by xtable 1.7-4 package -->
<!-- Fri Mar 13 09:09:38 2015 -->
<table border=1>
<tr> <th> transitions </th> <th> transversions </th> <th> titv </th> <th> alternate_allele_count </th>  </tr>
  <tr> <td align="right"> 306560 </td> <td align="right"> 148701 </td> <td align="right"> 2.06 </td> <td align="right">  10 </td> </tr>
  <tr> <td align="right"> 170521 </td> <td align="right"> 80446 </td> <td align="right"> 2.12 </td> <td align="right">   9 </td> </tr>
  <tr> <td align="right"> 205421 </td> <td align="right"> 98973 </td> <td align="right"> 2.08 </td> <td align="right">   8 </td> </tr>
  <tr> <td align="right"> 236947 </td> <td align="right"> 112333 </td> <td align="right"> 2.11 </td> <td align="right">   7 </td> </tr>
  <tr> <td align="right"> 278967 </td> <td align="right"> 133465 </td> <td align="right"> 2.09 </td> <td align="right">   6 </td> </tr>
  <tr> <td align="right"> 328155 </td> <td align="right"> 156074 </td> <td align="right"> 2.10 </td> <td align="right">   5 </td> </tr>
   </table>

Visualizing the results:

```r
ggplot(result) +
  geom_point(aes(x=alternate_allele_count, y=titv)) +
  xlab("Total Number of Sample Alleles with the Variant") +
  ylab("Ti/Tv") +
  ggtitle("Ti/Tv by Alternate Allele Count")
```

<img src="figure/titvByAlt-1.png" title="plot of chunk titvByAlt" alt="plot of chunk titvByAlt" style="display: block; margin: auto;" />

## Missingness Rate

For each variant, compute the missingness rate.  This query can be used to identify variants with a poor call rate.


```r
sortAndLimit <- "ORDER BY missingness_rate DESC, reference_name, start, reference_bases, alternate_bases LIMIT 1000"
result <- DisplayAndDispatchQuery("./sql/variant-level-missingness.sql",
                                  project=project,
                                  replacements=c(tableReplacement,
                                                 "#_ORDER_BY_"=sortAndLimit))
```

```
# Compute the ratio no-calls for each variant.
SELECT
  reference_name,
  start,
  END,
  reference_bases,
  alternate_bases,
  no_calls,
  all_calls,
  (no_calls/all_calls) AS missingness_rate
FROM (
  SELECT
    reference_name,
    start,
    END,
    reference_bases,
    GROUP_CONCAT(alternate_bases) WITHIN RECORD AS alternate_bases,
    SUM(call.genotype == -1) WITHIN RECORD AS no_calls,
    COUNT(call.genotype) WITHIN RECORD AS all_calls,
  FROM
      [va_aaa_pilot_data.5_genome_test_vcfs_no_calls]
    # Optionally add clause here to limit the query to a particular
    # region of the genome.
    #_WHERE_
  )
# Optionally add a clause here to sort and limit the results.
ORDER BY missingness_rate DESC, reference_name, start, reference_bases, alternate_bases LIMIT 1000
```
Number of rows returned by this query: 1000.

Displaying the first few results:
<!-- html table generated in R 3.1.2 by xtable 1.7-4 package -->
<!-- Fri Mar 13 09:09:43 2015 -->
<table border=1>
<tr> <th> reference_name </th> <th> start </th> <th> END </th> <th> reference_bases </th> <th> alternate_bases </th> <th> no_calls </th> <th> all_calls </th> <th> missingness_rate </th>  </tr>
  <tr> <td> chr1 </td> <td align="right"> 62202 </td> <td align="right"> 62204 </td> <td> T </td> <td> C </td> <td align="right">   4 </td> <td align="right">   4 </td> <td align="right"> 1.00 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 66161 </td> <td align="right"> 66163 </td> <td> A </td> <td> T </td> <td align="right">   2 </td> <td align="right">   2 </td> <td align="right"> 1.00 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 66274 </td> <td align="right"> 66277 </td> <td> A </td> <td> T </td> <td align="right">   6 </td> <td align="right">   6 </td> <td align="right"> 1.00 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 84306 </td> <td align="right"> 84308 </td> <td> C </td> <td> A </td> <td align="right">   2 </td> <td align="right">   2 </td> <td align="right"> 1.00 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 121008 </td> <td align="right"> 121010 </td> <td> C </td> <td> T </td> <td align="right">   2 </td> <td align="right">   2 </td> <td align="right"> 1.00 </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 724947 </td> <td align="right"> 724978 </td> <td> T </td> <td> A </td> <td align="right">  10 </td> <td align="right">  10 </td> <td align="right"> 1.00 </td> </tr>
   </table>

## Hardy-Weinberg Equilibrium

For each variant, compute the expected versus observed relationship between allele frequencies and genotype frequencies per the Hardy-Weinberg Equilibrium.


```r
sortAndLimit <- "ORDER BY ChiSq DESC, reference_name, start, alternate_bases LIMIT 1000"
result <- DisplayAndDispatchQuery("./sql/hardy-weinberg.sql",
                                  project=project,
                                  replacements=c(tableReplacement,
                                                 "#_ORDER_BY_"=sortAndLimit))
```

```
# The following query computes the Hardy-Weinberg equilibrium for variants.
SELECT
  reference_name,
  start,
  reference_bases,
  alternate_bases,
  OBS_HOM1,
  OBS_HET,
  OBS_HOM2,
  E_HOM1,
  E_HET,
  E_HOM2,

  # Chi Squared Calculation
  # SUM(((Observed - Expected)^2) / Expected )
  ROUND((POW(OBS_HOM1 - E_HOM1, 2) / E_HOM1)
  + (POW(OBS_HET - E_HET, 2) / E_HET)
  + (POW(OBS_HOM2 - E_HOM2, 2) / E_HOM2), 6)
  AS ChiSq,

  # Determine if Chi Sq value is significant
  IF((POW(OBS_HOM1 - E_HOM1, 2) / E_HOM1)
  + (POW(OBS_HET - E_HET, 2) / E_HET)
  + (POW(OBS_HOM2 - E_HOM2, 2) / E_HOM2)
  > 5.991, "TRUE", "FALSE") AS PVALUE_SIG

FROM (
    SELECT
      reference_name,
      start,
      reference_bases,
      alternate_bases,
      OBS_HOM1,
      OBS_HET,
      OBS_HOM2,

      # Expected AA
      # p^2
      # ((COUNT(AA) + (COUNT(Aa)/2) /
      #  SAMPLE_COUNT) ^ 2) * SAMPLE_COUNT
      ROUND(POW((OBS_HOM1 + (OBS_HET/2)) /
        SAMPLE_COUNT, 2) * SAMPLE_COUNT, 2)
        AS E_HOM1,

      # Expected Aa
      # 2pq
      # 2 * (COUNT(AA) + (COUNT(Aa)/2) / SAMPLE_COUNT) *
      # (COUNT(aa) + (COUNT(Aa)/2) / SAMPLE_COUNT)
      # * SAMPLE_COUNT
      ROUND(2 * ((OBS_HOM1 + (OBS_HET/2)) / SAMPLE_COUNT) *
        ((OBS_HOM2 + (OBS_HET/2)) / SAMPLE_COUNT)
        * SAMPLE_COUNT, 2)
        AS E_HET,

      # Expected aa
      # q^2
      # (COUNT(aa) + (COUNT(Aa)/2) /
      #  SAMPLE_COUNT) ^ 2 * SAMPLE_COUNT
      ROUND(POW((OBS_HOM2 + (OBS_HET/2)) /
        SAMPLE_COUNT, 2) * SAMPLE_COUNT, 2)
        AS E_HOM2,

  FROM (
    SELECT
      reference_name,
      start,
      reference_bases,
      alternate_bases,
      HOM_REF AS OBS_HOM1,
      HET AS OBS_HET,
      HOM_ALT AS OBS_HOM2,
      HOM_REF + HET + HOM_ALT AS SAMPLE_COUNT,
    FROM (
      SELECT
        reference_name,
        start,
        END,
        reference_bases,
        GROUP_CONCAT(alternate_bases) WITHIN RECORD AS alternate_bases,
        COUNT(alternate_bases) WITHIN RECORD AS num_alts,
        SUM(EVERY(0 = call.genotype)) WITHIN call AS HOM_REF,
        SUM(EVERY(1 = call.genotype)) WITHIN call AS HOM_ALT,
        SUM(SOME(0 = call.genotype)
          AND SOME(1 = call.genotype)) WITHIN call AS HET,
      FROM
        [va_aaa_pilot_data.5_genome_test_vcfs_no_calls]
      # Optionally add a clause here to limit the query to a particular
      # region of the genome.
      #_WHERE_
      HAVING
        # Skip 1/2 genotypes
        num_alts = 1
        )))
# Optionally add a clause here to sort and limit the results.
ORDER BY ChiSq DESC, reference_name, start, alternate_bases LIMIT 1000

Running query:   RUNNING  2.2s
Running query:   RUNNING  2.9s
Running query:   RUNNING  3.6s
Running query:   RUNNING  4.2s
Running query:   RUNNING  4.8s
```
Number of rows returned by this query: 1000.

Displaying the first few results:
<!-- html table generated in R 3.1.2 by xtable 1.7-4 package -->
<!-- Fri Mar 13 09:09:53 2015 -->
<table border=1>
<tr> <th> reference_name </th> <th> start </th> <th> reference_bases </th> <th> alternate_bases </th> <th> OBS_HOM1 </th> <th> OBS_HET </th> <th> OBS_HOM2 </th> <th> E_HOM1 </th> <th> E_HET </th> <th> E_HOM2 </th> <th> ChiSq </th> <th> PVALUE_SIG </th>  </tr>
  <tr> <td> chr1 </td> <td align="right"> 1647300 </td> <td> G </td> <td> A </td> <td align="right">   5 </td> <td align="right">   0 </td> <td align="right">   5 </td> <td align="right"> 2.50 </td> <td align="right"> 5.00 </td> <td align="right"> 2.50 </td> <td align="right"> 10.00 </td> <td> TRUE </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 3356634 </td> <td> T </td> <td> C </td> <td align="right">   5 </td> <td align="right">   0 </td> <td align="right">   5 </td> <td align="right"> 2.50 </td> <td align="right"> 5.00 </td> <td align="right"> 2.50 </td> <td align="right"> 10.00 </td> <td> TRUE </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 3523917 </td> <td> G </td> <td> A </td> <td align="right">   5 </td> <td align="right">   0 </td> <td align="right">   5 </td> <td align="right"> 2.50 </td> <td align="right"> 5.00 </td> <td align="right"> 2.50 </td> <td align="right"> 10.00 </td> <td> TRUE </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 12109450 </td> <td> T </td> <td> C </td> <td align="right">   5 </td> <td align="right">   0 </td> <td align="right">   5 </td> <td align="right"> 2.50 </td> <td align="right"> 5.00 </td> <td align="right"> 2.50 </td> <td align="right"> 10.00 </td> <td> TRUE </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 16739392 </td> <td> T </td> <td> C </td> <td align="right">   5 </td> <td align="right">   0 </td> <td align="right">   5 </td> <td align="right"> 2.50 </td> <td align="right"> 5.00 </td> <td align="right"> 2.50 </td> <td align="right"> 10.00 </td> <td> TRUE </td> </tr>
  <tr> <td> chr1 </td> <td align="right"> 17416594 </td> <td> T </td> <td> C </td> <td align="right">   5 </td> <td align="right">   0 </td> <td align="right">   5 </td> <td align="right"> 2.50 </td> <td align="right"> 5.00 </td> <td align="right"> 2.50 </td> <td align="right"> 10.00 </td> <td> TRUE </td> </tr>
   </table>

## Heterozygous Haplotype
For each variant within the X and Y chromosome, identify heterozygous variants in male genomes.

First we use our sample information to determine which genomes are male.  

```r
maleSampleIds <- paste("'", filter(sampleInfo, gender == "Male")$call_call_set_name, "'", sep="", collapse=",")
```


```r
sortAndLimit <- "ORDER BY reference_name, start, alternate_bases, call.call_set_name LIMIT 1000"
result <- DisplayAndDispatchQuery("./sql/sex-chromosome-heterozygous-haplotypes.sql",
                                  project=project,
                                  replacements=c(tableReplacement,
                                                 "_MALE_SAMPLE_IDS_"=maleSampleIds,
                                                 "#_ORDER_BY_"=sortAndLimit))
```

```
# Retrieve heterozygous haplotype calls on chromosomes X and Y.
SELECT
  reference_name,
  start,
  end,
  reference_bases,
  GROUP_CONCAT(alternate_bases) WITHIN RECORD AS alternate_bases,
  call.call_set_name,
  GROUP_CONCAT(STRING(call.genotype)) WITHIN call AS genotype,
FROM
  [va_aaa_pilot_data.5_genome_test_gvcfs_no_calls]
WHERE
  reference_name IN ('chrX', 'chrY')
OMIT
  call if (2 > COUNT(call.genotype))
  OR EVERY(call.genotype <= 0)
  OR EVERY(call.genotype = 1)
HAVING call.call_set_name IN ('NA12877','NA12882','NA12883','NA12884','NA12886','NA12888','NA12889','NA12891','NA12893')
# Optionally add a clause here to sort and limit the results.
ORDER BY reference_name, start, alternate_bases, call.call_set_name LIMIT 1000
```
Number of rows returned by this query: .

Displaying the first few results:

```
Error in UseMethod("xtable"): no applicable method for 'xtable' applied to an object of class "NULL"
```

# Removing variants from the Cohort

To remove a variant from a variant set in the Genomics API:
* See the [variant delete](https://cloud.google.com/genomics/v1beta2/reference/variants/delete) method.

To instead mark a variant as problematic so that downstream analyses can filter it out:
* See the [variant update](https://cloud.google.com/genomics/v1beta2/reference/variants/update) method

To remove variants from BigQuery only:
* Materialize the results of queries that include the non-problematic variants to a new table.
* Alternatively, write a custom filtering job similar to what we explored in [Part 2: Data Conversion](./Data-Conversion.md) of this codelab.

