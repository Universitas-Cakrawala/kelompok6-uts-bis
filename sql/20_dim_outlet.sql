-- UTS K6/T2/k9. SCD Type 1: koreksi nama/lokasi outlet menimpa atribut lama.
-- Grain: satu baris per outlet_id. Slice hanya OUT-A, tetapi FK outlet tetap eksplisit.
CREATE SEQUENCE IF NOT EXISTS seq_outlet_sk START 1;
CREATE TABLE IF NOT EXISTS dim_outlet (
    outlet_sk BIGINT PRIMARY KEY,
    outlet_id VARCHAR NOT NULL UNIQUE,
    nama_outlet VARCHAR NOT NULL,
    kota VARCHAR,
    tipe VARCHAR,
    aktif BOOLEAN,
    dibuka_sejak DATE
);
-- Loader memakai nextval('seq_outlet_sk') untuk ID baru dan mempertahankan SK saat Type 1.
INSERT INTO dim_outlet
SELECT -1, 'UNKNOWN', 'Outlet tidak diketahui', NULL, NULL, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM dim_outlet WHERE outlet_sk = -1);
