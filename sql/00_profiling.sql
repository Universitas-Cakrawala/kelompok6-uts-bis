-- ============================================================
-- 00_profiling.sql — DIBERIKAN. Enam query, tanpa kecerdikan.
-- Jalankan sebelum menulis satu baris transformasi. Ganti {D} dengan folder seed kamu:
--   T1: data/raw/t1_kampus        T2: data/raw/t2_umkm        T3: data/raw/t3_publik/<slice>
-- Versi otomatis: python -m pipeline.profile --topic t3 --slice k1
-- ============================================================

-- 1. Berapa barisnya, dan berapa kunci bisnis uniknya?
SELECT count(*) AS baris, count(DISTINCT transaction_id) AS id_unik
FROM read_csv_auto('{D}/transactions.csv', all_varchar=true);

-- 2. Null / kosong di kolom yang akan jadi kunci join
SELECT count(*) FILTER (WHERE customer_id IS NULL OR customer_id = '') AS customer_kosong,
       count(*) FILTER (WHERE outlet_id  IS NULL OR outlet_id  = '') AS outlet_kosong
FROM read_csv_auto('{D}/transactions.csv', all_varchar=true);

-- 3. Duplikat pada kandidat grain
SELECT count(*) AS duplikat
FROM (SELECT transaction_id, product_id FROM read_csv_auto('{D}/transaction_items.csv', all_varchar=true)
      GROUP BY 1, 2 HAVING count(*) > 1);

-- 4. Rentang tidak wajar: nilai di luar batas akal
SELECT min(TRY_CAST(qty AS INT)) AS qty_min, max(TRY_CAST(qty AS INT)) AS qty_max,
       min(TRY_CAST(harga_satuan AS BIGINT)) AS harga_min,
       max(TRY_CAST(harga_satuan AS BIGINT)) AS harga_max
FROM read_csv_auto('{D}/transaction_items.csv', all_varchar=true);

-- 5. Nilai di luar domain: berapa varian yang sebenarnya ada?
SELECT status, count(*) AS baris
FROM read_csv_auto('{D}/transactions.csv', all_varchar=true) GROUP BY 1 ORDER BY 2 DESC;

-- 6. Format tanggal/timestamp: satu kolom, dua dunia
SELECT count(*) FILTER (WHERE tanggal_waktu LIKE '%Z') AS utc_tanpa_zona,
       count(*) FILTER (WHERE tanggal_waktu NOT LIKE '%Z') AS waktu_lokal
FROM read_csv_auto('{D}/transactions.csv', all_varchar=true);
