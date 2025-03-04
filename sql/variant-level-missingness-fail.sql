# Select positions where the missingness rate across all samples is above a defined cutoff.

SELECT 
variant_id,
"variant_missingness" AS failure_reason,
missingness_rate,
FROM (
  SELECT
  variant_id,
  reference_name,
  start,
  end,
  reference_bases,
  alternate_bases,
  called_allele_count,
  1 - (called_allele_count)/sample_count AS missingness_rate,
  sample_count
  FROM (
    SELECT
    variant_id,
    reference_name,
    start,
    end,
    reference_bases,
    GROUP_CONCAT(alt.alternate_bases) WITHIN alt AS alternate_bases,
    SUM(call.genotype >= 0) WITHIN RECORD AS called_allele_count,
    FROM
    [_THE_EXPANDED_TABLE_]
    # Optionally add clause here to limit the query to a particular
    # region of the genome.
    #_WHERE_
    HAVING
      LENGTH(reference_bases) = 1 AND
      LENGTH(alternate_bases) = 1
  ) AS g
  CROSS JOIN (
    SELECT
    COUNT(call.call_set_name) AS sample_count
    FROM (
      SELECT 
      call.call_set_name
      FROM
      [_THE_EXPANDED_TABLE_]
      GROUP BY 
      call.call_set_name)) AS count )
WHERE
missingness_rate > _CUTOFF_
# Optionally add a clause here to sort and limit the results.
#_ORDER_BY_
