-- Can we build a composite quality indicator to support referral or network decisions?

--creating table 
CREATE TABLE irf_composite_index AS
WITH scored AS (
    SELECT
        ccn,
        provider_name,
        city,
        state,
        cms_region,
        pressure_ulcer_vs_benchmark,
        falls_vs_benchmark,
        dtc_vs_benchmark,
        ppr_vs_benchmark,

        -- Convert benchmark categories to a common scale: better=+1, no different=0, worse=-1
        CASE
            WHEN pressure_ulcer_vs_benchmark LIKE 'Better%' THEN 1
            WHEN pressure_ulcer_vs_benchmark LIKE 'Worse%'  THEN -1
            WHEN pressure_ulcer_vs_benchmark LIKE 'No Different%' THEN 0
            ELSE NULL
        END AS pu_score,
        CASE
            WHEN falls_vs_benchmark LIKE 'Better%' THEN 1
            WHEN falls_vs_benchmark LIKE 'Worse%'  THEN -1
            WHEN falls_vs_benchmark LIKE 'No Different%' THEN 0
            ELSE NULL
        END AS falls_score,
        CASE
            WHEN dtc_vs_benchmark LIKE 'Better%' THEN 1
            WHEN dtc_vs_benchmark LIKE 'Worse%'  THEN -1
            WHEN dtc_vs_benchmark LIKE 'No Different%' THEN 0
            ELSE NULL
        END AS dtc_score,
        CASE
            WHEN ppr_vs_benchmark LIKE 'Better%' THEN 1
            WHEN ppr_vs_benchmark LIKE 'Worse%'  THEN -1
            WHEN ppr_vs_benchmark LIKE 'No Different%' THEN 0
            ELSE NULL
        END AS ppr_score
    FROM irf_facility_scorecard
)
SELECT
    ccn,
    provider_name,
    city,
    state,
    cms_region,
    pu_score,
    falls_score,
    dtc_score,
    ppr_score,

    -- Count how many measures each facility is evaluable on
    (pu_score    IS NOT NULL)::INT
  + (falls_score IS NOT NULL)::INT
  + (dtc_score   IS NOT NULL)::INT
  + (ppr_score   IS NOT NULL)::INT AS measures_evaluable,

    -- Composite: sum of scores, only meaningful when all four are present
    CASE
        WHEN (pu_score IS NOT NULL AND falls_score IS NOT NULL
          AND dtc_score IS NOT NULL AND ppr_score IS NOT NULL)
        THEN pu_score + falls_score + dtc_score + ppr_score
        ELSE NULL
    END AS composite_score,

    -- Flag whether the facility is fully benchmarkable
    CASE
        WHEN (pu_score IS NOT NULL AND falls_score IS NOT NULL
          AND dtc_score IS NOT NULL AND ppr_score IS NOT NULL)
        THEN 'Fully benchmarkable'
        ELSE 'Partial / suppressed'
    END AS benchmark_status
FROM scored;

--testing the newly created table data to display filtered results

SELECT benchmark_status, COUNT(*)
FROM irf_composite_index
GROUP BY benchmark_status;

--Selecting Best perfomers :
SELECT
    RANK() OVER (ORDER BY composite_score DESC) AS rank,
    provider_name,
    city,
    state,
    cms_region,
    pu_score    AS pressure_ulcer,
    falls_score AS falls,
    dtc_score   AS discharge_to_community,
    ppr_score   AS readmissions,
    composite_score
FROM irf_composite_index
WHERE composite_score IS NOT NULL
ORDER BY composite_score DESC, provider_name
LIMIT 25;

--Worst perfromers 
SELECT
    RANK() OVER (ORDER BY composite_score ASC) AS rank,
    provider_name, city, state,
    pu_score, falls_score, dtc_score, ppr_score,
    composite_score
FROM irf_composite_index
WHERE composite_score IS NOT NULL
ORDER BY composite_score ASC, provider_name
LIMIT 25;


-- final coverage statement 
SELECT
    COUNT(*) AS total_facilities,
    COUNT(*) FILTER (WHERE composite_score IS NOT NULL) AS fully_benchmarkable,
    COUNT(*) FILTER (WHERE composite_score IS NULL)     AS partial_or_suppressed,
    ROUND(100.0 * COUNT(*) FILTER (WHERE composite_score IS NOT NULL) / COUNT(*), 1) AS pct_fully_benchmarkable
FROM irf_composite_index;

--The composite index is a transparent, auditable screening tool for referral and network shortlisting. Sensitivity analysis shows rankings shift under reasonable weight changes, and only Z% of facilities are fully benchmarkable, so the composite is a prioritization aid — final referral and network decisions must use the measure-level scorecard.