-- Which IRFs perform best and worst on key quality measures (e.g., pressure ulcers, falls with major injury, functional outcomes, readmissions)?

CREATE TABLE irf_facility_scorecard AS
SELECT
    ccn,
    MAX(provider_name) AS provider_name,
    MAX(city)          AS city,
    MAX(state)         AS state,
    MAX(cms_region)    AS cms_region,

    -- Pressure ulcer: pull numeric SIR + benchmark label
    MAX(CASE WHEN measure_code = 'I_006_01_SIR'          THEN NULLIF(score,'Not Available')::NUMERIC END) AS pressure_ulcer_sir,
    MAX(CASE WHEN measure_code = 'I_006_01_COMP_PERF'    THEN score END)                                   AS pressure_ulcer_vs_benchmark,

    -- Falls with major injury
    MAX(CASE WHEN measure_code = 'I_015_01_SIR'          THEN NULLIF(score,'Not Available')::NUMERIC END) AS falls_major_injury_sir,
    MAX(CASE WHEN measure_code = 'I_015_01_COMP_PERF'    THEN score END)                                   AS falls_vs_benchmark,

    -- Discharge to community (higher = better)
    MAX(CASE WHEN measure_code = 'I_019_02_DTC_RS_RATE'  THEN NULLIF(score,'Not Available')::NUMERIC END) AS dtc_rs_rate_pct,
    MAX(CASE WHEN measure_code = 'I_019_02_DTC_COMP_PERF' THEN score END)                                  AS dtc_vs_benchmark,

    -- Potentially preventable readmissions (lower = better)
    MAX(CASE WHEN measure_code = 'I_017_01_PPR_PD_OBS_RATE' THEN NULLIF(score,'Not Available')::NUMERIC END) AS ppr_obs_rate_pct,
    MAX(CASE WHEN measure_code = 'I_017_01_PPR_PD_COMP_PERF' THEN score END)                                  AS ppr_vs_benchmark

FROM hospital_rehab_data
GROUP BY ccn;

--tested data 
SELECT * FROM irf_facility_scorecard

---- SHOWCASE THIS: BEST (lowest SIR) — statistically better performers
SELECT provider_name, city, state, pressure_ulcer_sir
FROM irf_facility_scorecard
WHERE pressure_ulcer_vs_benchmark = 'Better than the National Benchmark'
ORDER BY pressure_ulcer_sir ASC
LIMIT 10;

-- SHOWCASE THIS: WORST (highest SIR) — statistically worse performers
SELECT provider_name, city, state, pressure_ulcer_sir
FROM irf_facility_scorecard
WHERE pressure_ulcer_vs_benchmark = 'Worse than the National Benchmark'
ORDER BY pressure_ulcer_sir DESC
LIMIT 10;


-- How does facility quality vary by state and CMS region, and are there geographic patterns?
SELECT * FROM hospital_rehab_data

CREATE OR REPLACE VIEW irf_state_quality AS
SELECT
    state,
    MAX(cms_region)                                   AS cms_region,
    COUNT(*)                                          AS facilities,

    -- Pressure ulcer
    ROUND(AVG(pressure_ulcer_sir), 3)                 AS avg_pressure_ulcer_sir,
    COUNT(*) FILTER (WHERE pressure_ulcer_vs_benchmark = 'Better than the National Benchmark') AS pu_better,
    COUNT(*) FILTER (WHERE pressure_ulcer_vs_benchmark = 'Worse than the National Benchmark')  AS pu_worse,

    -- Falls w/ major injury
    ROUND(AVG(falls_major_injury_sir), 3)             AS avg_falls_sir,
    COUNT(*) FILTER (WHERE falls_vs_benchmark = 'Better than the National Benchmark')          AS falls_better,
    COUNT(*) FILTER (WHERE falls_vs_benchmark = 'Worse than the National Benchmark')           AS falls_worse,

    -- Discharge to community (higher = better)
    ROUND(AVG(dtc_rs_rate_pct), 2)                    AS avg_dtc_rate_pct,
    COUNT(*) FILTER (WHERE dtc_vs_benchmark = 'Better than the National Rate')                 AS dtc_better,
    COUNT(*) FILTER (WHERE dtc_vs_benchmark = 'Worse than the National Rate')                  AS dtc_worse,

    -- Readmissions (lower = better)
    ROUND(AVG(ppr_obs_rate_pct), 2)                   AS avg_ppr_rate_pct,
    COUNT(*) FILTER (WHERE ppr_vs_benchmark = 'Better than the National Rate')                 AS ppr_better,
    COUNT(*) FILTER (WHERE ppr_vs_benchmark = 'Worse than the National Rate')                  AS ppr_worse

FROM irf_facility_scorecard
WHERE state IS NOT NULL
GROUP BY state;

--Created another table to a parallel view rolled up to the 10 CMS regions:
CREATE OR REPLACE VIEW irf_region_quality AS
SELECT
    cms_region,
    COUNT(*)                                          AS facilities,
    COUNT(DISTINCT state)                             AS states_covered,

    ROUND(AVG(pressure_ulcer_sir), 3)                 AS avg_pressure_ulcer_sir,
    COUNT(*) FILTER (WHERE pressure_ulcer_vs_benchmark = 'Better than the National Benchmark') AS pu_better,
    COUNT(*) FILTER (WHERE pressure_ulcer_vs_benchmark = 'Worse than the National Benchmark')  AS pu_worse,

    ROUND(AVG(falls_major_injury_sir), 3)             AS avg_falls_sir,
    COUNT(*) FILTER (WHERE falls_vs_benchmark = 'Better than the National Benchmark')          AS falls_better,
    COUNT(*) FILTER (WHERE falls_vs_benchmark = 'Worse than the National Benchmark')           AS falls_worse,

    ROUND(AVG(dtc_rs_rate_pct), 2)                    AS avg_dtc_rate_pct,
    COUNT(*) FILTER (WHERE dtc_vs_benchmark = 'Better than the National Rate')                 AS dtc_better,
    COUNT(*) FILTER (WHERE dtc_vs_benchmark = 'Worse than the National Rate')                  AS dtc_worse,

    ROUND(AVG(ppr_obs_rate_pct), 2)                   AS avg_ppr_rate_pct,
    COUNT(*) FILTER (WHERE ppr_vs_benchmark = 'Better than the National Rate')                 AS ppr_better,
    COUNT(*) FILTER (WHERE ppr_vs_benchmark = 'Worse than the National Rate')                  AS ppr_worse

FROM irf_facility_scorecard
WHERE cms_region IS NOT NULL
GROUP BY cms_region
ORDER BY cms_region;

--SHOWCASE THIS: View to look at new table to answer: Which states have the best discharge-to-community performance?
SELECT state, cms_region, facilities,
       avg_dtc_rate_pct,
       dtc_better,
       dtc_worse,
       ROUND(100.0 * dtc_better / NULLIF(dtc_better + dtc_worse, 0), 1) AS pct_outperforming
FROM irf_state_quality
WHERE facilities >= 5                         -- suppress tiny-N states
ORDER BY avg_dtc_rate_pct DESC
LIMIT 10;

-- SHOWCASE THIS: Which states have the highest readmission burden?

SELECT state, cms_region, facilities,
       avg_ppr_rate_pct,
       ppr_worse,
       ROUND(100.0 * ppr_worse / NULLIF(ppr_better + ppr_worse, 0), 1) AS pct_underperforming
FROM irf_state_quality
WHERE facilities >= 5
ORDER BY avg_ppr_rate_pct DESC
LIMIT 10;

--SHOWCASE THIS POWER BI:Region-level rollup (this is your Power BI map page data)
SELECT * FROM irf_region_quality;

--SHOWCASE THIS: Are there geographic patterns? A single "hotspot" query, which states are simultaneously worse-than-benchmark on readmissions AND pressure ulcers? 
SELECT state, cms_region, facilities,
       ppr_worse  AS readmission_worse_count,
       pu_worse   AS pressure_ulcer_worse_count,
       ROUND(100.0 * ppr_worse / NULLIF(facilities,0), 1) AS pct_ppr_worse,
       ROUND(100.0 * pu_worse  / NULLIF(facilities,0), 1) AS pct_pu_worse
FROM irf_state_quality
WHERE facilities >= 5
  AND ppr_worse  > 0
  AND pu_worse   > 0
ORDER BY pct_ppr_worse DESC, pct_pu_worse DESC;

--SHOWCASE THIS: The regional comparison table for the README
SELECT
    cms_region,
    facilities,
    states_covered,
    avg_dtc_rate_pct,
    dtc_better,
    dtc_worse,
    avg_ppr_rate_pct,
    ppr_worse,
    ROUND(100.0 * ppr_worse / NULLIF(facilities,0), 1) AS pct_ppr_worse
FROM irf_region_quality
ORDER BY avg_dtc_rate_pct DESC;

-- Do facilities that perform well on one measure also perform well on others, or is quality highly measure-specific?
--Created the new view as a select statement  
CREATE OR REPLACE VIEW irf_measure_coperformance AS
WITH b AS (
    SELECT
        ccn,
        (pressure_ulcer_vs_benchmark = 'Better than the National Benchmark')::INT AS pu_better,
        (pressure_ulcer_vs_benchmark = 'Worse  than the National Benchmark')::INT AS pu_worse,
        (falls_vs_benchmark          = 'Better than the National Benchmark')::INT AS falls_better,
        (falls_vs_benchmark          = 'Worse  than the National Benchmark')::INT AS falls_worse,
        (dtc_vs_benchmark            = 'Better than the National Rate')::INT       AS dtc_better,
        (dtc_vs_benchmark            = 'Worse  than the National Rate')::INT       AS dtc_worse,
        (ppr_vs_benchmark            = 'Better than the National Rate')::INT       AS ppr_better,
        (ppr_vs_benchmark            = 'Worse  than the National Rate')::INT       AS ppr_worse
    FROM irf_facility_scorecard
)
SELECT 'Pressure Ulcer x Falls' AS measure_pair,
       SUM(pu_better * falls_better) AS both_better,
       SUM(pu_worse  * falls_worse)  AS both_worse,
       SUM(pu_better * falls_worse) + SUM(pu_worse * falls_better) AS mixed,
       SUM(GREATEST(pu_better, pu_worse) * GREATEST(falls_better, falls_worse)) AS evaluable
FROM b
UNION ALL
SELECT 'Pressure Ulcer x Readmission',
       SUM(pu_better * ppr_better), SUM(pu_worse * ppr_worse),
       SUM(pu_better * ppr_worse) + SUM(pu_worse * ppr_better),
       SUM(GREATEST(pu_better, pu_worse) * GREATEST(ppr_better, ppr_worse))
FROM b
UNION ALL
SELECT 'Falls x Readmission',
       SUM(falls_better * ppr_better), SUM(falls_worse * ppr_worse),
       SUM(falls_better * ppr_worse) + SUM(falls_worse * ppr_better),
       SUM(GREATEST(falls_better, falls_worse) * GREATEST(ppr_better, ppr_worse))
FROM b
UNION ALL
SELECT 'Discharge to Community x Readmission',
       SUM(dtc_better * ppr_better), SUM(dtc_worse * ppr_worse),
       SUM(dtc_better * ppr_worse) + SUM(dtc_worse * ppr_better),
       SUM(GREATEST(dtc_better, dtc_worse) * GREATEST(ppr_better, ppr_worse))
FROM b
UNION ALL
SELECT 'Pressure Ulcer x Discharge to Community',
       SUM(pu_better * dtc_better), SUM(pu_worse * dtc_worse),
       SUM(pu_better * dtc_worse) + SUM(pu_worse * dtc_better),
       SUM(GREATEST(pu_better, pu_worse) * GREATEST(dtc_better, dtc_worse))
FROM b
UNION ALL
SELECT 'Falls x Discharge to Community',
       SUM(falls_better * dtc_better), SUM(falls_worse * dtc_worse),
       SUM(falls_better * dtc_worse) + SUM(falls_worse * dtc_better),
       SUM(GREATEST(falls_better, falls_worse) * GREATEST(dtc_better, dtc_worse))
FROM b;

-- SHOWCASE THIS: select statement to view the table  for  quality is measure-specific — performance on one measure tells you little about another. BENCHMARK SCORES
SELECT
    measure_pair,
    evaluable,
    both_better,
    both_worse,
    mixed,
    ROUND(100.0 * both_better / NULLIF(evaluable,0), 1) AS pct_both_better,
    ROUND(100.0 * both_worse  / NULLIF(evaluable,0), 1) AS pct_both_worse
FROM irf_measure_coperformance
ORDER BY pct_both_better DESC;

-- Which facilities have missing or suppressed data (footnoted results), and how does that data quality issue affect the ability to benchmark?

-- Suppression rate per measure family
SELECT
    'Pressure Ulcer' AS measure_family,
    COUNT(*) AS total_facilities,
    COUNT(*) FILTER (WHERE pressure_ulcer_vs_benchmark = 'Not Available') AS suppressed,
    ROUND(100.0 * COUNT(*) FILTER (WHERE pressure_ulcer_vs_benchmark = 'Not Available') / COUNT(*), 1) AS pct_suppressed
FROM irf_facility_scorecard
UNION ALL
SELECT 'Falls w/ Major Injury',
    COUNT(*),
    COUNT(*) FILTER (WHERE falls_vs_benchmark = 'Not Available'),
    ROUND(100.0 * COUNT(*) FILTER (WHERE falls_vs_benchmark = 'Not Available') / COUNT(*), 1)
FROM irf_facility_scorecard
UNION ALL
SELECT 'Discharge to Community',
    COUNT(*),
    COUNT(*) FILTER (WHERE dtc_vs_benchmark = 'Not Available'),
    ROUND(100.0 * COUNT(*) FILTER (WHERE dtc_vs_benchmark = 'Not Available') / COUNT(*), 1)
FROM irf_facility_scorecard
UNION ALL
SELECT 'Readmissions (PPR)',
    COUNT(*),
    COUNT(*) FILTER (WHERE ppr_vs_benchmark = 'Not Available'),
    ROUND(100.0 * COUNT(*) FILTER (WHERE ppr_vs_benchmark = 'Not Available') / COUNT(*), 1)
FROM irf_facility_scorecard;

--List of suppressed facilities
SELECT
    ccn,
    provider_name,
    city,
    state,
    cms_region,
    pressure_ulcer_vs_benchmark,
    falls_vs_benchmark,
    dtc_vs_benchmark,
    ppr_vs_benchmark
FROM irf_facility_scorecard
WHERE pressure_ulcer_vs_benchmark = 'Not Available'
   OR falls_vs_benchmark          = 'Not Available'
   OR dtc_vs_benchmark            = 'Not Available'
   OR ppr_vs_benchmark            = 'Not Available'
ORDER BY state, provider_name;

--Do suppressed facilities differ from reporting ones? (proves the bias claim)
WITH facility_size AS (
    SELECT
        s.ccn,
        s.provider_name,
        s.state,
        s.pressure_ulcer_vs_benchmark,
        MAX(CASE WHEN h.measure_code = 'I_006_01_ELIGCASES'
                 THEN NULLIF(REPLACE(h.score, ',', ''), 'Not Available')::NUMERIC END) AS pressure_ulcer_eligible_cases,
        MAX(CASE WHEN h.measure_code = 'I_019_02_DTC_VOLUME'
                 THEN NULLIF(REPLACE(h.score, ',', ''), 'Not Available')::NUMERIC END) AS dtc_volume
    FROM irf_facility_scorecard s
    LEFT JOIN hospital_rehab_data h ON h.ccn = s.ccn
    GROUP BY s.ccn, s.provider_name, s.state, s.pressure_ulcer_vs_benchmark
)
SELECT
    CASE WHEN pressure_ulcer_vs_benchmark = 'Not Available'
         THEN 'Suppressed' ELSE 'Reporting' END AS group_label,
    COUNT(*) AS facilities,
    ROUND(AVG(pressure_ulcer_eligible_cases), 1) AS avg_pressure_ulcer_eligible_cases,
    ROUND(AVG(dtc_volume), 1)                    AS avg_dtc_volume
FROM facility_size
GROUP BY 1;