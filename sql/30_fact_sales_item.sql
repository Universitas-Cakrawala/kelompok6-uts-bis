-- UTS K6/T2/k9. GRAIN: satu baris untuk satu item_id pada satu transaksi OUT-A
-- bertanggal lokal WIB 2025-01-01 s.d. 2025-06-30, setelah deduplikasi identik.
-- Header konflik, item konflik/FK produk hilang, dan transaksi PAID dengan qty negatif
-- masuk karantina staging; tidak masuk fact sampai diperbaiki. REFUND/VOID tetap disimpan
-- untuk hitungan status, tetapi tidak berkontribusi ke nilai_paid_rp.
-- Degenerate dimension: transaction_id; item_id adalah natural key fact/upsert.
CREATE TABLE IF NOT EXISTS fact_sales_item (
    item_id VARCHAR PRIMARY KEY,
    transaction_id VARCHAR NOT NULL,
    outlet_sk BIGINT NOT NULL REFERENCES dim_outlet(outlet_sk),
    date_sk INTEGER NOT NULL,
    product_sk BIGINT NOT NULL REFERENCES dim_product(product_sk),
    customer_sk BIGINT NOT NULL REFERENCES dim_customer(customer_sk),
    waktu_wib TIMESTAMP NOT NULL,
    status_transaksi VARCHAR NOT NULL,
    -- qty_item: NON-ADDITIVE tanpa filter status; refund berisi tanda qty campuran.
    qty_item INTEGER NOT NULL,
    -- harga_satuan_rp: NON-ADDITIVE; harga per unit, jangan SUM.
    harga_satuan_rp DECIMAL(18,2) NOT NULL,
    -- diskon_item_rp: NON-ADDITIVE lintas status; nominal sumber per baris item.
    diskon_item_rp DECIMAL(18,2) NOT NULL,
    -- qty_paid: ADDITIVE pada baris PAID valid; nol untuk REFUND/VOID.
    qty_paid INTEGER NOT NULL,
    -- nilai_paid_rp: ADDITIVE pada tanggal/produk/outlet/pelanggan untuk PAID valid;
    -- 0 untuk REFUND/VOID. Bukan nilai bersih setelah refund atau laba.
    nilai_paid_rp DECIMAL(18,2) NOT NULL,
    CHECK (status_transaksi IN ('PAID','VOID','REFUND')),
    CHECK (harga_satuan_rp > 0),
    CHECK (diskon_item_rp >= 0)
);
-- Kontrak transformasi staging -> fact (desain, bukan perintah load):
--   status=PAID: qty_item > 0, qty_paid=qty_item,
--                nilai_paid_rp=qty_item*harga_satuan_rp-diskon_item_rp.
--   status=REFUND/VOID: qty_paid=0, nilai_paid_rp=0.
--   tanggal_wib=CAST(waktu_wib AS DATE), date_sk=YYYYMMDD dari dim_date.
--   FK date_sk bersifat logis karena generator dim_date yang diberikan memakai CTAS tanpa PK;
--   kontrol load wajib memastikan tepat satu baris dim_date per date_sk.
--   JOIN dim_date, dim_product (satu versi dalam interval), dim_outlet, dim_customer
--   semuanya dari fact; outlet_sk dipilih dari OUT-A pada header tervalidasi.
--   Setiap item_id harus menghasilkan tepat satu baris. Nilai header total_bayar
--   tidak dimasukkan ke fact karena dapat terulang pada setiap item.
