-- Loader Kelompok 6 T2/k9, sesuai pipeline/DESIGN_load.md.
-- Driver: .venv/bin/python -m pipeline.load --topic t2 --slice k9 --twice
-- Staging full replace, dimensi/key/histori persisten, fact MERGE by item_id.
-- Seluruh perubahan tabel satu transaksi. SQL ini khusus T2/k9.
-- SCD memakai tanggal snapshot benar-benar dibaca dalam zona WIB.
-- Dua perubahan produk pada hari yang sama ditolak karena grain versi DATE.
-- Database CTAS dari loader lama harus diarsipkan sebelum rebuild pertama.
BEGIN TRANSACTION;
SET TimeZone = 'Asia/Jakarta';
SELECT CASE WHEN '{TOPIC}' = 't2' AND '{SLICE}' = 'k9' THEN TRUE
            ELSE error('load.sql hanya mendukung topic t2 slice k9') END;
SELECT CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.tables t
    WHERE t.table_name IN ('dim_product','dim_outlet','dim_customer','fact_sales_item')
      AND t.table_schema = 'main'
      AND NOT EXISTS (SELECT 1 FROM duckdb_constraints() c
                      WHERE c.table_name=t.table_name AND c.constraint_type='PRIMARY KEY')
) THEN error('Schema legacy tanpa PK. Arsipkan database lalu rebuild, jangan menghapus histori secara otomatis')
ELSE TRUE END;

CREATE OR REPLACE TABLE stg_outlets AS
SELECT * FROM read_csv_auto('{D}/outlets.csv', all_varchar=true);
CREATE OR REPLACE TABLE stg_products AS
SELECT * FROM read_csv_auto('{D}/products.csv', all_varchar=true);
CREATE OR REPLACE TABLE stg_customers AS
SELECT * FROM read_csv_auto('{D}/customers.csv', all_varchar=true);
CREATE OR REPLACE TABLE stg_transaction_raw AS
SELECT * FROM read_csv_auto('{D}/transactions.csv', all_varchar=true);
CREATE OR REPLACE TABLE stg_item_raw AS
SELECT * FROM read_csv_auto('{D}/transaction_items.csv', all_varchar=true);

CREATE OR REPLACE TABLE stg_source_manifest AS
SELECT 'outlets.csv' AS source_file, count(*) AS row_count, bit_xor(hash(to_json(s))) AS fingerprint FROM stg_outlets s
UNION ALL SELECT 'products.csv', count(*), bit_xor(hash(to_json(s))) FROM stg_products s
UNION ALL SELECT 'customers.csv', count(*), bit_xor(hash(to_json(s))) FROM stg_customers s
UNION ALL SELECT 'transactions.csv', count(*), bit_xor(hash(to_json(s))) FROM stg_transaction_raw s
UNION ALL SELECT 'transaction_items.csv', count(*), bit_xor(hash(to_json(s))) FROM stg_item_raw s;

CREATE OR REPLACE TABLE stg_outlet_source AS
SELECT DISTINCT NULLIF(trim(outlet_id),'') AS outlet_id, NULLIF(trim(nama_outlet),'') AS nama_outlet,
    NULLIF(trim(kota),'') AS kota, NULLIF(trim(tipe),'') AS tipe,
    CASE WHEN lower(trim(aktif)) IN ('ya','yes','true','1') THEN TRUE
         WHEN lower(trim(aktif)) IN ('tidak','no','false','0') THEN FALSE END AS aktif,
    TRY_CAST(dibuka_sejak AS DATE) AS dibuka_sejak FROM stg_outlets;
CREATE OR REPLACE TABLE stg_customer_source AS
SELECT DISTINCT NULLIF(trim(customer_id),'') AS customer_id, NULLIF(trim(nama_pelanggan),'') AS nama_pelanggan,
    NULLIF(trim(kota),'') AS kota, TRY_CAST(tanggal_daftar AS DATE) AS tanggal_daftar FROM stg_customers;
CREATE OR REPLACE TABLE stg_product_source AS
SELECT DISTINCT NULLIF(trim(product_id),'') AS product_id, NULLIF(trim(nama_produk),'') AS nama_produk,
    NULLIF(trim(kategori),'') AS kategori, TRY_CAST(harga_satuan AS DECIMAL(18,2)) AS harga_referensi_rp,
    TRY_CAST(harga_berlaku_dari AS DATE) AS harga_berlaku_dari_sumber,
    CASE WHEN lower(trim(aktif)) IN ('ya','yes','true','1') THEN TRUE
         WHEN lower(trim(aktif)) IN ('tidak','no','false','0') THEN FALSE END AS aktif FROM stg_products;
-- Master ambigu adalah blocking untuk seluruh snapshot.
SELECT CASE WHEN
    EXISTS (SELECT 1 FROM stg_outlet_source WHERE outlet_id IS NULL OR outlet_id='UNKNOWN' OR nama_outlet IS NULL)
    OR EXISTS (SELECT 1 FROM stg_customer_source WHERE customer_id IS NULL OR customer_id IN ('UNKNOWN','ANONIM'))
    OR EXISTS (SELECT 1 FROM stg_product_source WHERE product_id IS NULL OR product_id='UNKNOWN' OR nama_produk IS NULL)
    OR EXISTS (SELECT outlet_id FROM stg_outlet_source GROUP BY 1 HAVING count(*)>1)
    OR EXISTS (SELECT customer_id FROM stg_customer_source GROUP BY 1 HAVING count(*)>1)
    OR EXISTS (SELECT product_id FROM stg_product_source GROUP BY 1 HAVING count(*)>1)
    OR (SELECT count(*) FROM stg_outlet_source WHERE outlet_id='OUT-A')<>1
THEN error('Master kosong/ambigu atau OUT-A tidak tepat satu') ELSE TRUE END;

CREATE OR REPLACE TABLE stg_tx_parsed AS
SELECT t.*, NULLIF(trim(transaction_id),'') AS tx_key, NULLIF(trim(outlet_id),'') AS outlet_key,
    NULLIF(trim(customer_id),'') AS customer_key, upper(trim(status)) AS status_transaksi,
    CASE WHEN upper(trim(tanggal_waktu)) LIKE '%Z'
         THEN TRY_CAST(trim(tanggal_waktu) AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta'
         ELSE TRY_CAST(trim(tanggal_waktu) AS TIMESTAMP) END AS waktu_wib
FROM stg_transaction_raw t;
CREATE OR REPLACE TABLE stg_tx_candidates AS
SELECT DISTINCT tx_key FROM stg_tx_parsed WHERE outlet_key='OUT-A'
    AND CAST(waktu_wib AS DATE)>=DATE '2025-01-01'
    AND CAST(waktu_wib AS DATE)<DATE '2025-07-01';
-- Konflik juga diperiksa pada header ID yang sama di luar slice.
CREATE OR REPLACE TABLE stg_tx_conflicts AS
SELECT tx_key FROM stg_tx_parsed
WHERE tx_key IN (SELECT tx_key FROM stg_tx_candidates)
GROUP BY tx_key
HAVING count(DISTINCT struct_pack(o:=outlet_id,c:=customer_id,w:=tanggal_waktu,s:=status,b:=total_bayar))>1;
CREATE OR REPLACE TABLE stg_transaction_k9 AS
SELECT DISTINCT tx_key AS transaction_id, outlet_key AS outlet_id, customer_key AS customer_id,
    tanggal_waktu AS tanggal_waktu_raw, waktu_wib, status_transaksi, status_transaksi AS status,
    TRY_CAST(total_bayar AS DECIMAL(18,2)) AS total_bayar
FROM stg_tx_parsed t
WHERE outlet_key='OUT-A' AND CAST(waktu_wib AS DATE)>=DATE '2025-01-01'
    AND CAST(waktu_wib AS DATE)<DATE '2025-07-01' AND tx_key IS NOT NULL
    AND status_transaksi IN ('PAID','VOID','REFUND')
    AND NOT EXISTS (SELECT 1 FROM stg_tx_conflicts x WHERE x.tx_key=t.tx_key);

CREATE OR REPLACE TABLE stg_item_parsed AS
SELECT i.*, NULLIF(trim(item_id),'') AS item_key, NULLIF(trim(transaction_id),'') AS tx_key,
    NULLIF(trim(product_id),'') AS product_key, TRY_CAST(qty AS INTEGER) AS qty_item,
    TRY_CAST(harga_satuan AS DECIMAL(18,2)) AS harga_satuan_rp,
    TRY_CAST(diskon AS DECIMAL(18,2)) AS diskon_item_rp
FROM stg_item_raw i;
CREATE OR REPLACE TABLE stg_item_candidates AS
SELECT i.* FROM stg_item_parsed i
WHERE EXISTS (SELECT 1 FROM stg_tx_candidates t WHERE t.tx_key=i.tx_key);
CREATE OR REPLACE TABLE stg_item_conflicts AS
SELECT item_key FROM stg_item_parsed
WHERE item_key IN (SELECT item_key FROM stg_item_candidates)
GROUP BY item_key
HAVING count(DISTINCT struct_pack(t:=transaction_id,p:=product_id,q:=qty,h:=harga_satuan,d:=diskon))>1;
CREATE OR REPLACE TABLE stg_item_k9 AS
SELECT DISTINCT i.* FROM stg_item_candidates i
WHERE NOT EXISTS (SELECT 1 FROM stg_item_conflicts x WHERE x.item_key=i.item_key);
CREATE OR REPLACE TABLE stg_invalid_paid AS
SELECT DISTINCT t.transaction_id
FROM stg_transaction_k9 t JOIN stg_item_candidates i ON i.tx_key=t.transaction_id
WHERE t.status_transaksi='PAID' AND (i.qty_item IS NULL OR i.qty_item<=0
    OR i.qty_item*i.harga_satuan_rp-i.diskon_item_rp<0);

CREATE OR REPLACE TABLE stg_quarantine AS
WITH problems AS (
    SELECT 'transactions.csv' AS source_file, COALESCE(t.tx_key,'<EMPTY>') AS source_key,
        'HEADER_CONFLICT' AS reason, 'blocking' AS severity, to_json(t) AS payload
    FROM stg_tx_parsed t JOIN stg_tx_conflicts x USING(tx_key)
    UNION ALL
    SELECT 'transactions.csv', COALESCE(tx_key,'<EMPTY>'), 'TIME_OR_KEY_INVALID','blocking',to_json(t)
    FROM stg_tx_parsed t WHERE outlet_key='OUT-A' AND (waktu_wib IS NULL OR tx_key IS NULL)
    UNION ALL
    SELECT 'transactions.csv',tx_key,'STATUS_INVALID','blocking',to_json(t)
    FROM stg_tx_parsed t WHERE tx_key IN (SELECT tx_key FROM stg_tx_candidates)
        AND (status_transaksi IS NULL OR status_transaksi NOT IN ('PAID','VOID','REFUND'))
    UNION ALL
    SELECT 'transaction_items.csv',COALESCE(i.item_key,'<EMPTY>'),'HEADER_CONFLICT','blocking',to_json(i)
    FROM stg_item_candidates i JOIN stg_tx_conflicts x USING(tx_key)
    UNION ALL
    SELECT 'transaction_items.csv',COALESCE(i.item_key,'<EMPTY>'),'ITEM_CONFLICT','blocking',to_json(i)
    FROM stg_item_candidates i JOIN stg_item_conflicts x USING(item_key)
    UNION ALL
    SELECT 'transaction_items.csv',COALESCE(i.item_key,'<EMPTY>'),'ITEM_INVALID','blocking',to_json(i)
    FROM stg_item_candidates i WHERE i.item_key IS NULL OR i.tx_key IS NULL
        OR i.qty_item IS NULL OR i.harga_satuan_rp IS NULL OR i.diskon_item_rp IS NULL
        OR i.harga_satuan_rp<=0 OR i.diskon_item_rp<0 OR i.product_key IS NULL
        OR NOT EXISTS (SELECT 1 FROM stg_product_source p WHERE p.product_id=i.product_key)
    UNION ALL
    SELECT 'transaction_items.csv',COALESCE(i.item_key,'<EMPTY>'),'PAID_TRANSACTION_INVALID','blocking',to_json(i)
    FROM stg_item_candidates i JOIN stg_invalid_paid x ON x.transaction_id=i.tx_key
    UNION ALL
    SELECT 'transactions.csv',t.transaction_id,'HEADER_WITHOUT_ITEM','warning',to_json(t)
    FROM stg_transaction_k9 t WHERE NOT EXISTS (SELECT 1 FROM stg_item_candidates i WHERE i.tx_key=t.transaction_id)
    UNION ALL
    SELECT 'transactions.csv',t.transaction_id,'CUSTOMER_UNKNOWN','warning',to_json(t)
    FROM stg_transaction_k9 t WHERE t.customer_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM stg_customer_source c WHERE c.customer_id=t.customer_id)
    UNION ALL
    SELECT 'transaction_items.csv',COALESCE(i.item_key,'<EMPTY>'),'VOID_NEGATIVE_QTY','warning',to_json(i)
    FROM stg_item_candidates i JOIN stg_transaction_k9 t ON t.transaction_id=i.tx_key
    WHERE t.status_transaksi='VOID' AND i.qty_item<0
    UNION ALL
    SELECT 'transaction_items.csv',COALESCE(item_key,'<EMPTY>'),'HEADER_MISSING_SCOPE_UNKNOWN','warning',to_json(i)
    FROM stg_item_parsed i WHERE NOT EXISTS (SELECT 1 FROM stg_tx_parsed t WHERE t.tx_key=i.tx_key)
)
SELECT DISTINCT * FROM problems;
CREATE OR REPLACE TABLE stg_item_valid AS
SELECT DISTINCT i.item_key AS item_id, i.tx_key AS transaction_id, i.product_key AS product_id,
    i.qty, i.harga_satuan, i.diskon, i.qty_item, i.harga_satuan_rp, i.diskon_item_rp
FROM stg_item_k9 i JOIN stg_transaction_k9 t ON t.transaction_id=i.tx_key
WHERE i.item_key IS NOT NULL AND i.qty_item IS NOT NULL
    AND i.harga_satuan_rp>0 AND i.diskon_item_rp>=0
    AND EXISTS (SELECT 1 FROM stg_product_source p WHERE p.product_id=i.product_key)
    AND NOT EXISTS (SELECT 1 FROM stg_invalid_paid x WHERE x.transaction_id=i.tx_key);

-- Kalender sesuai SQL dosen, relasi date_sk diperiksa secara logis.
CREATE OR REPLACE TABLE dim_date AS
SELECT CAST(strftime(d,'%Y%m%d') AS INTEGER) AS date_sk, d AS full_date,
    CAST(year(d) AS INTEGER) AS tahun, CAST(quarter(d) AS INTEGER) AS triwulan,
    CAST(month(d) AS INTEGER) AS bulan, strftime(d,'%B') AS nama_bulan,
    CAST(week(d) AS INTEGER) AS pekan_iso, CAST(day(d) AS INTEGER) AS hari,
    CAST(dayofweek(d) AS INTEGER) AS hari_ke, strftime(d,'%A') AS nama_hari,
    CAST(dayofweek(d) IN (0,6) AS BOOLEAN) AS akhir_pekan
FROM (SELECT unnest(generate_series(DATE '2024-01-01',DATE '2027-12-31',INTERVAL 1 DAY)) AS d);
INSERT INTO dim_date SELECT -1,DATE '1900-01-01',1900,0,0,'TIDAK DIKETAHUI',0,0,-1,'TIDAK DIKETAHUI',FALSE;

-- DDL identik dengan berkas 20_dim_*.sql dan 30_fact_sales_item.sql.
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
INSERT INTO dim_product
SELECT -1, 'UNKNOWN', 'Produk tidak diketahui', 'Tidak diketahui', NULL, NULL,
       NULL, DATE '1900-01-01', DATE '9999-12-31', TRUE
WHERE NOT EXISTS (SELECT 1 FROM dim_product WHERE product_sk = -1);
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
INSERT INTO dim_outlet
SELECT -1, 'UNKNOWN', 'Outlet tidak diketahui', NULL, NULL, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM dim_outlet WHERE outlet_sk = -1);
CREATE SEQUENCE IF NOT EXISTS seq_customer_sk START 1;
CREATE TABLE IF NOT EXISTS dim_customer (
    customer_sk BIGINT PRIMARY KEY,
    customer_id VARCHAR NOT NULL UNIQUE,
    nama_pelanggan VARCHAR,
    kota VARCHAR,
    tanggal_daftar DATE
);
INSERT INTO dim_customer
SELECT -1, 'UNKNOWN', 'Pelanggan tidak diketahui', NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM dim_customer WHERE customer_sk = -1);
INSERT INTO dim_customer
SELECT -2, 'ANONIM', 'Pembeli anonim', NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM dim_customer WHERE customer_sk = -2);
CREATE TABLE IF NOT EXISTS fact_sales_item (
    item_id VARCHAR PRIMARY KEY,
    transaction_id VARCHAR NOT NULL,
    outlet_sk BIGINT NOT NULL REFERENCES dim_outlet(outlet_sk),
    date_sk INTEGER NOT NULL,
    product_sk BIGINT NOT NULL REFERENCES dim_product(product_sk),
    customer_sk BIGINT NOT NULL REFERENCES dim_customer(customer_sk),
    waktu_wib TIMESTAMP NOT NULL,
    status_transaksi VARCHAR NOT NULL,
    qty_item INTEGER NOT NULL,
    harga_satuan_rp DECIMAL(18,2) NOT NULL,
    diskon_item_rp DECIMAL(18,2) NOT NULL,
    qty_paid INTEGER NOT NULL,
    nilai_paid_rp DECIMAL(18,2) NOT NULL,
    CHECK (status_transaksi IN ('PAID','VOID','REFUND')),
    CHECK (harga_satuan_rp > 0),
    CHECK (diskon_item_rp >= 0)
);


MERGE INTO dim_outlet d USING stg_outlet_source s ON d.outlet_id=s.outlet_id
WHEN MATCHED THEN UPDATE SET nama_outlet=s.nama_outlet,kota=s.kota,tipe=s.tipe,aktif=s.aktif,dibuka_sejak=s.dibuka_sejak
WHEN NOT MATCHED THEN INSERT VALUES (nextval('seq_outlet_sk'),s.outlet_id,s.nama_outlet,s.kota,s.tipe,s.aktif,s.dibuka_sejak);
MERGE INTO dim_customer d USING stg_customer_source s ON d.customer_id=s.customer_id
WHEN MATCHED THEN UPDATE SET nama_pelanggan=s.nama_pelanggan,kota=s.kota,tanggal_daftar=s.tanggal_daftar
WHEN NOT MATCHED THEN INSERT VALUES (nextval('seq_customer_sk'),s.customer_id,s.nama_pelanggan,s.kota,s.tanggal_daftar);

SELECT CASE WHEN EXISTS (
    SELECT product_id FROM dim_product GROUP BY 1 HAVING count(*) FILTER (WHERE is_current)<>1
) THEN error('Jumlah versi produk aktif tidak tepat satu') ELSE TRUE END;
CREATE OR REPLACE TABLE stg_product_changes AS
SELECT s.*,d.product_sk AS previous_sk,d.valid_from AS previous_from
FROM stg_product_source s JOIN dim_product d ON d.product_id=s.product_id AND d.is_current
WHERE d.nama_produk IS DISTINCT FROM s.nama_produk OR d.kategori IS DISTINCT FROM s.kategori
    OR d.harga_referensi_rp IS DISTINCT FROM s.harga_referensi_rp OR d.aktif IS DISTINCT FROM s.aktif;
SELECT CASE WHEN EXISTS (SELECT 1 FROM stg_product_changes WHERE previous_from>=current_date)
    THEN error('Perubahan produk kedua pada hari yang sama memerlukan resolusi versi lebih rinci') ELSE TRUE END;
UPDATE dim_product SET valid_to=current_date,is_current=FALSE
WHERE product_sk IN (SELECT previous_sk FROM stg_product_changes);
INSERT INTO dim_product
SELECT nextval('seq_product_sk'),product_id,nama_produk,kategori,harga_referensi_rp,
    harga_berlaku_dari_sumber,aktif,current_date,DATE '9999-12-31',TRUE FROM stg_product_changes;
-- Seed pertama tiap ID hanya mengklaim atribut as-known dari snapshot.
INSERT INTO dim_product
SELECT nextval('seq_product_sk'),s.product_id,s.nama_produk,s.kategori,s.harga_referensi_rp,
    s.harga_berlaku_dari_sumber,s.aktif,DATE '1900-01-01',DATE '9999-12-31',TRUE
FROM stg_product_source s WHERE NOT EXISTS (SELECT 1 FROM dim_product d WHERE d.product_id=s.product_id);
UPDATE dim_product SET harga_berlaku_dari_sumber=s.harga_berlaku_dari_sumber
FROM stg_product_source s WHERE dim_product.product_id=s.product_id AND dim_product.is_current;
SELECT CASE WHEN
    EXISTS (SELECT product_id FROM dim_product GROUP BY 1 HAVING count(*) FILTER(WHERE is_current)<>1)
    OR EXISTS (SELECT product_id,valid_from FROM dim_product GROUP BY 1,2 HAVING count(*)>1)
    OR EXISTS (SELECT 1 FROM dim_product a JOIN dim_product b ON a.product_id=b.product_id
        AND a.product_sk<b.product_sk AND a.valid_from<b.valid_to AND b.valid_from<a.valid_to)
THEN error('Versi produk duplikat atau interval bertumpang tindih') ELSE TRUE END;

CREATE OR REPLACE TABLE stg_item_lookup AS
SELECT i.item_id,t.transaction_id,o.outlet_sk,d.date_sk,p.product_sk,
    COALESCE(c.customer_sk,CASE WHEN t.customer_id IS NULL THEN -2 ELSE -1 END)::BIGINT AS customer_sk,
    t.waktu_wib,t.status_transaksi,i.qty_item,i.harga_satuan_rp,i.diskon_item_rp,
    CASE WHEN t.status_transaksi='PAID' THEN i.qty_item ELSE 0 END AS qty_paid,
    CAST(CASE WHEN t.status_transaksi='PAID' THEN i.qty_item*i.harga_satuan_rp-i.diskon_item_rp ELSE 0 END AS DECIMAL(18,2)) AS nilai_paid_rp
FROM stg_item_valid i JOIN stg_transaction_k9 t USING(transaction_id)
LEFT JOIN dim_date d ON d.full_date=CAST(t.waktu_wib AS DATE)
LEFT JOIN dim_product p ON p.product_id=i.product_id
    AND CAST(t.waktu_wib AS DATE)>=p.valid_from AND CAST(t.waktu_wib AS DATE)<p.valid_to
LEFT JOIN dim_outlet o ON o.outlet_id=t.outlet_id
LEFT JOIN dim_customer c ON c.customer_id=t.customer_id;
SELECT CASE WHEN EXISTS (SELECT item_id FROM stg_item_lookup GROUP BY 1 HAVING count(*)<>1)
    OR EXISTS (SELECT 1 FROM stg_item_lookup WHERE date_sk IS NULL OR product_sk IS NULL OR outlet_sk IS NULL)
THEN error('Lookup dimensi tidak tepat satu per item') ELSE TRUE END;
-- Jangan menimpa key fact yang dimiliki cakupan lain.
SELECT CASE WHEN EXISTS (
    SELECT 1 FROM fact_sales_item f JOIN stg_item_lookup s USING(item_id)
    JOIN dim_outlet o ON o.outlet_sk=f.outlet_sk
    WHERE o.outlet_id<>'OUT-A' OR CAST(f.waktu_wib AS DATE)<DATE '2025-01-01'
        OR CAST(f.waktu_wib AS DATE)>=DATE '2025-07-01'
) THEN error('item_id bertabrakan dengan fact di luar k9') ELSE TRUE END;
MERGE INTO fact_sales_item f USING stg_item_lookup s ON f.item_id=s.item_id
WHEN MATCHED THEN UPDATE SET transaction_id=s.transaction_id,outlet_sk=s.outlet_sk,date_sk=s.date_sk,
    product_sk=s.product_sk,customer_sk=s.customer_sk,waktu_wib=s.waktu_wib,status_transaksi=s.status_transaksi,
    qty_item=s.qty_item,harga_satuan_rp=s.harga_satuan_rp,diskon_item_rp=s.diskon_item_rp,
    qty_paid=s.qty_paid,nilai_paid_rp=s.nilai_paid_rp
WHEN NOT MATCHED THEN INSERT VALUES (s.item_id,s.transaction_id,s.outlet_sk,s.date_sk,s.product_sk,s.customer_sk,
    s.waktu_wib,s.status_transaksi,s.qty_item,s.harga_satuan_rp,s.diskon_item_rp,s.qty_paid,s.nilai_paid_rp);
DELETE FROM fact_sales_item f WHERE
    EXISTS (SELECT 1 FROM dim_outlet o WHERE o.outlet_sk=f.outlet_sk AND o.outlet_id='OUT-A')
    AND CAST(f.waktu_wib AS DATE)>=DATE '2025-01-01' AND CAST(f.waktu_wib AS DATE)<DATE '2025-07-01'
    AND NOT EXISTS (SELECT 1 FROM stg_item_valid s WHERE s.item_id=f.item_id);

CREATE OR REPLACE TABLE stg_reconciliation AS
SELECT t.transaction_id,t.total_bayar,SUM(i.qty_item*i.harga_satuan_rp-i.diskon_item_rp) AS nilai_item,
    'warning' AS severity
FROM stg_transaction_k9 t JOIN stg_item_valid i USING(transaction_id)
GROUP BY t.transaction_id,t.total_bayar
HAVING t.total_bayar IS DISTINCT FROM SUM(i.qty_item*i.harga_satuan_rp-i.diskon_item_rp);
SELECT CASE WHEN
    (SELECT count(*) FROM stg_item_valid)<>(SELECT count(*) FROM fact_sales_item f JOIN dim_outlet o USING(outlet_sk)
        WHERE o.outlet_id='OUT-A' AND CAST(f.waktu_wib AS DATE)>=DATE '2025-01-01'
        AND CAST(f.waktu_wib AS DATE)<DATE '2025-07-01')
    OR EXISTS (SELECT date_sk FROM dim_date GROUP BY 1 HAVING count(*)>1)
THEN error('Rekonsiliasi item atau kalender tidak cocok') ELSE TRUE END;
COMMIT;
