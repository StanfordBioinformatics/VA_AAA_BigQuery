SELECT
Gene,
Sample_id,
COUNT(Tx_Start) AS count
FROM(
  SELECT
  Gene,
  Chr,
  Tx_Start,
  Tx_End,
  Pos,
  Sample_id,
  REF,
  ALT,
  Genotype,
  type AS var_type,
  clinicalsignificance AS Clin_Significance,
  acmg_Phenotype,
  ACMG_age_onset
  FROM
  [gbsc-gcp-project-mvp:va_aaa_pilot_data.56_acmg_variants] AS var_acmg
  JOIN 
  (
    SELECT 
    CONCAT(STRING("chr"),
           STRING(chromosome)) AS contig,
    start,
    type,
    clinicalsignificance
    FROM
    [google.com:biggene:annotations.clinvar] 
    WHERE
    type = 'single nucleotide variant'
    AND clinicalsignificance = 'Pathogenic'
  ) AS clin
  ON
  var_acmg.Chr = clin.contig
  AND var_acmg.Pos = clin.start)
GROUP BY
Gene,
Sample_id
#ORDER BY
#  Gene ASC,
#  Sample_id ASC;