-- Created Table and then uploaded csv file data into table
CREATE TABLE hospital_rehab_data (
    ccn                    VARCHAR(6),
    provider_name          TEXT,
    address_line1          TEXT,
    address_line2          TEXT,
    city                   TEXT,
    state                  CHAR(2),
    zip                    VARCHAR(10),
    county                 TEXT,
    telephone              VARCHAR(20),
    cms_region             INTEGER,
    measure_code           TEXT,
    score                  TEXT,          
    footnote               TEXT,
    start_date             DATE,
    end_date               DATE,
    measure_date_range     TEXT
);

SELECT * FROM hospital_rehab_data

--Created Table to decipher the measure_code in the hospital_rehab_data table to display to end users what each medical code is and what is means
CREATE TABLE measure_reference (
    measure_code     TEXT PRIMARY KEY,
    measure_family   TEXT,   -- e.g. 'Pressure Ulcer', 'Falls', 'Readmission'
    measure_name     TEXT,   -- human-readable
    score_type       TEXT,   -- 'SIR', 'OBS_RATE', 'COMP_PERF', 'CI_LOWER', ...
    higher_is_better BOOLEAN -- direction of "good"
);

--To test that the table was made
SELECT * FROM measure_reference

--updated the values to be added into the table to showcase what each code is 
INSERT INTO measure_reference VALUES
 ('I_006_01_SIR','Pressure Ulcer','Pressure ulcer standardized infection ratio','SIR','false'),
 ('I_006_01_COMP_PERF','Pressure Ulcer','Pressure ulcer vs national benchmark','COMP_PERF','false'),
 ('I_015_01_SIR','Falls','Falls with major injury SIR','SIR','false'),
 ('I_015_01_COMP_PERF','Falls','Falls vs national benchmark','COMP_PERF','false'),
 ('I_019_02_DTC_RS_RATE','Discharge to Community','Risk-standardized DTC rate (%)','OBS_RATE','true'),
 ('I_019_02_DTC_COMP_PERF','Discharge to Community','DTC vs national rate','COMP_PERF','true'),
 ('I_017_01_PPR_PD_OBS_RATE','Readmissions','Potentially preventable readmission observed rate (%)','OBS_RATE','false'),
 ('I_017_01_PPR_PD_COMP_PERF','Readmissions','PPR vs national rate','COMP_PERF','false');

--tested to view table
SELECT * FROM measure_reference