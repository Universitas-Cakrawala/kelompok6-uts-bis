-- ============================================================
-- 10_dim_date.sql — DIBERIKAN LENGKAP. Ini bukan checkpoint, ini alat.
-- Konformed dimension: SEMUA fact di warehouse ini menunjuk ke sini.
-- ============================================================

CREATE OR REPLACE TABLE dim_date AS
SELECT CAST(strftime(d, '%Y%m%d') AS INTEGER) AS date_sk,   -- kunci: YYYYMMDD, bukan urutan
       d AS full_date,
       CAST(year(d)  AS INTEGER) AS tahun,
       CAST(quarter(d) AS INTEGER) AS triwulan,
       CAST(month(d) AS INTEGER) AS bulan,
       strftime(d, '%B') AS nama_bulan,
       CAST(week(d)  AS INTEGER) AS pekan_iso,
       CAST(day(d)   AS INTEGER) AS hari,
       CAST(dayofweek(d) AS INTEGER) AS hari_ke,            -- 0 = Minggu
       strftime(d, '%A') AS nama_hari,
       CAST(dayofweek(d) IN (0, 6) AS BOOLEAN) AS akhir_pekan
FROM (SELECT unnest(generate_series(DATE '2024-01-01', DATE '2027-12-31', INTERVAL 1 DAY)) AS d);

-- Anggota Unknown: banyak pipeline gagal bukan karena datanya salah, tapi karena ada baris
-- yang tidak punya tanggal. Baris seperti itu tetap harus punya tempat.
INSERT INTO dim_date
SELECT -1, DATE '1900-01-01', 1900, 0, 0, 'TIDAK DIKETAHUI', 0, 0, -1, 'TIDAK DIKETAHUI', FALSE;
