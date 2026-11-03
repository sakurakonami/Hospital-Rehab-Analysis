--Cleaned Data up
ALTER TABLE hospital_rehab_data
    DROP COLUMN address_line1,
    DROP COLUMN address_line2,
    DROP COLUMN footnote,
    DROP COLUMN measure_date_range;