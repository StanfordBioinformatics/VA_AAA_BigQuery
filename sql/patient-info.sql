# Identify samples as cases or controls based on AAA size

SELECT 
  IlluminaID AS sample_id,
  AAA_SIZE,
  CASE WHEN AAA_SIZE >= 3 
      THEN 'CASE'
    WHEN AAA_SIZE < 3 
      THEN 'CONTROL'
    ELSE 'NONE'
  END AS COHORT,
FROM
  [_PATIENT_INFO_]
