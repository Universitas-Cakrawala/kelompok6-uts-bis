-- UTS K6/T2/k9. SCD Type 2: identitas produk tetap, atribut produk dapat berubah.
-- Grain: satu versi atribut untuk satu product_id; interval [valid_from, valid_to).
-- Seed awal berasal dari satu snapshot products.csv: atribut masa lalu tidak diketahui.
-- valid_from awal 1900-01-01 adalah penanda backfill "as known", bukan bukti harga historis.
-- Harga transaksi fact selalu memakai transaction_items.harga_satuan.
CREATE SEQUENCE IF NOT EXISTS seq_product_sk START 1;
CREATE TABLE IF NOT EXISTS dim_product (
    product_sk BIGINT PRIMARY KEY,
    product_id VARCHAR NOT NULL,
    nama_produk VARCHAR NOT NULL,
    kategori VARCHAR,
    harga_referensi_rp DECIMAL(18,2),
    harga_berlaku_dari_sumber DATE,
    aktif BOOLEAN,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    is_current BOOLEAN NOT NULL,
    CHECK (valid_from < valid_to)
);
-- Loader mengalokasikan nextval('seq_product_sk') sekali per versi baru; -1 untuk Unknown.
-- UNIQUE(product_id, valid_from) dan satu is_current=true per product_id
-- diperiksa pada staging/load karena partial unique index tidak diasumsikan tersedia.
-- Lookup historis: fact.tanggal_wib >= valid_from AND fact.tanggal_wib < valid_to.
-- Seed awal satu baris per product_id dari snapshot dengan valid_from=1900-01-01.
-- Perubahan snapshot berikutnya menutup versi lama tepat pada tanggal efektif yang teramati;
-- jangan memakai harga_berlaku_dari_sumber untuk menciptakan versi yang tidak ada.
INSERT INTO dim_product
SELECT -1, 'UNKNOWN', 'Produk tidak diketahui', 'Tidak diketahui', NULL, NULL,
       NULL, DATE '1900-01-01', DATE '9999-12-31', TRUE
WHERE NOT EXISTS (SELECT 1 FROM dim_product WHERE product_sk = -1);
