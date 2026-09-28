-- UTS K6/T2/k9. SCD Type 1: koreksi nama/kota pelanggan menimpa atribut lama.
-- Grain: satu baris per customer_id. Telepon tidak diperlukan untuk keputusan UTS.
-- Customer kosong pada transaksi adalah pelanggan anonim, bukan FK rusak.
CREATE SEQUENCE IF NOT EXISTS seq_customer_sk START 1;
CREATE TABLE IF NOT EXISTS dim_customer (
    customer_sk BIGINT PRIMARY KEY,
    customer_id VARCHAR NOT NULL UNIQUE,
    nama_pelanggan VARCHAR,
    kota VARCHAR,
    tanggal_daftar DATE
);
-- -1 = Unknown untuk ID nonkosong yang tak dapat dicocokkan; -2 = ANONIM untuk ID kosong.
-- Loader memakai nextval('seq_customer_sk') untuk ID baru; koreksi Type 1 tidak mengubah SK.
INSERT INTO dim_customer
SELECT -1, 'UNKNOWN', 'Pelanggan tidak diketahui', NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM dim_customer WHERE customer_sk = -1);
INSERT INTO dim_customer
SELECT -2, 'ANONIM', 'Pembeli anonim', NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM dim_customer WHERE customer_sk = -2);
