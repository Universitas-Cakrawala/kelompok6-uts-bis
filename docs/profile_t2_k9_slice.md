# Bukti profiling T2/k9 — Outlet A, Januari–Juni 2025

Sumber hanya lima CSV pada `data/raw/t2_umkm/`. Semua query di bawah merupakan `SELECT` pada view baca-saja; tidak ada warehouse yang dibangun. Waktu bertanda `Z` diparse sebagai UTC dan dikonversi ke WIB (`Asia/Jakarta`); waktu tanpa zona diasumsikan WIB. Filter memakai tanggal WIB `[2025-01-01, 2025-07-01)` dan `outlet_id = OUT-A`.

## Ringkasan cakupan

| Pemeriksaan | Hasil | Catatan |
|---|---:|---|
| Header seluruh sumber | 15.892 | Profil bawaan; mencakup outlet lain |
| Header slice | 2.578 | 2.543 ID transaksi unik |
| Item terkait slice | 5.074 | 5.032 ID item unik; dipilih dengan EXISTS, bukan JOIN |
| Header bertanda Z pada slice | 375 | 0 timestamp gagal parse pada seluruh sumber |
| Rentang transaksi slice | 1 Jan–30 Jun 2025 | Berdasarkan WIB |
| Header PAID/VOID/REFUND | 2.504 / 43 / 31 | PAID mencakup kapitalisasi berbeda |

## Enam query yang menjadi bukti `perkiraan_baris`

Definisi `raw_transactions`, `raw_transaction_items`, `raw_products` sama dengan view baca-saja dari CSV (`read_csv_auto(..., all_varchar=true)`). Query di sini identik dengan SQL test YAML; hasil adalah jumlah pelanggaran awal sumber dan bukan hasil sesudah penanganan.

### transaction_id_duplikat_k9

- Hasil: **34**; `expected: fail`, severity `blocking`.
- Unit dan alasan: ID transaksi kembar pada Outlet A/periode menyebabkan item ter-join berulang; unitnya kelompok ID.

```sql
WITH slice AS (SELECT t.* FROM raw_transactions t WHERE t.outlet_id = 'OUT-A' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) >= DATE '2025-01-01' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) < DATE '2025-07-01') SELECT count(*) FROM (SELECT transaction_id FROM slice GROUP BY 1 HAVING count(*) > 1);
```

### transaction_id_konflik_k9

- Hasil: **4**; `expected: fail`, severity `blocking`.
- Unit dan alasan: Header dengan ID sama tetapi atribut berbeda tidak punya aturan pilih yang aman dan harus dikarantina; unitnya ID.

```sql
WITH slice AS (SELECT t.* FROM raw_transactions t WHERE t.outlet_id = 'OUT-A' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) >= DATE '2025-01-01' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) < DATE '2025-07-01') SELECT count(*) FROM (SELECT transaction_id FROM slice GROUP BY 1 HAVING count(DISTINCT concat_ws('|',coalesce(outlet_id,''),coalesce(customer_id,''),coalesce(tanggal_waktu,''),coalesce(status,''),coalesce(total_bayar,''))) > 1);
```

### item_id_duplikat_k9

- Hasil: **42**; `expected: fail`, severity `blocking`.
- Unit dan alasan: Item ID kembar menggandakan nilai penjualan; unitnya kelompok item_id sebelum deduplikasi.

```sql
WITH slice AS (SELECT t.* FROM raw_transactions t WHERE t.outlet_id = 'OUT-A' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) >= DATE '2025-01-01' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) < DATE '2025-07-01'), item_slice AS (SELECT i.* FROM raw_transaction_items i WHERE EXISTS (SELECT 1 FROM slice t WHERE t.transaction_id=i.transaction_id)) SELECT count(*) FROM (SELECT item_id FROM item_slice GROUP BY 1 HAVING count(*) > 1);
```

### qty_negatif_paid_k9

- Hasil: **92**; `expected: fail`, severity `blocking`.
- Unit dan alasan: Qty negatif pada transaksi PAID membuat nilai item tidak layak dijumlah; unitnya baris item mentah, tanpa JOIN pengganda.

```sql
WITH slice AS (SELECT t.* FROM raw_transactions t WHERE t.outlet_id = 'OUT-A' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) >= DATE '2025-01-01' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) < DATE '2025-07-01') SELECT count(*) FROM raw_transaction_items i WHERE TRY_CAST(i.qty AS INTEGER) < 0 AND EXISTS (SELECT 1 FROM slice t WHERE t.transaction_id=i.transaction_id AND upper(trim(t.status)) = 'PAID');
```

### transaksi_tanpa_item_k9

- Hasil: **21**; `expected: fail`, severity `warning`.
- Unit dan alasan: Header tanpa item membuat total header tidak bisa dijelaskan pada grain fact item; unitnya baris header.

```sql
WITH slice AS (SELECT t.* FROM raw_transactions t WHERE t.outlet_id = 'OUT-A' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) >= DATE '2025-01-01' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) < DATE '2025-07-01') SELECT count(*) FROM slice t WHERE NOT EXISTS (SELECT 1 FROM raw_transaction_items i WHERE i.transaction_id=t.transaction_id);
```

### item_produk_orphan_k9

- Hasil: **0**; `expected: pass`, severity `blocking`.
- Unit dan alasan: Item tanpa produk tidak bisa dipetakan ke dimensi produk; unitnya baris item mentah.

```sql
WITH slice AS (SELECT t.* FROM raw_transactions t WHERE t.outlet_id = 'OUT-A' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) >= DATE '2025-01-01' AND CAST(CASE WHEN upper(trim(t.tanggal_waktu)) LIKE '%Z' THEN TRY_CAST(t.tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta' ELSE TRY_CAST(t.tanggal_waktu AS TIMESTAMP) END AS DATE) < DATE '2025-07-01') SELECT count(*) FROM raw_transaction_items i WHERE EXISTS (SELECT 1 FROM slice t WHERE t.transaction_id=i.transaction_id) AND NOT EXISTS (SELECT 1 FROM raw_products p WHERE p.product_id=i.product_id);
```

## Temuan tambahan untuk desain

- Duplikasi header slice: 34 ID, 35 baris berlebih. Empat ID memiliki atribut header yang saling bertentangan; jangan memilih salah satunya secara arbitrer.
- Duplikasi item: 42 ID, 42 baris berlebih; seluruh 42 kelompok tersebut identik pada kolom CSV, sehingga boleh dide-duplikasi deterministik.
- Ada 92 baris item qty negatif pada transaksi PAID dan 2 pada VOID. Sebanyak 90 transaksi PAID berkaitan dengan 212 item unik; seluruh transaksi PAID tersebut dikarantina agar nilainya tidak parsial. VOID tetap disimpan dengan nilai_paid_rp=0 dan anomali tanda dicatat sebagai warning.
- Ada 21 header slice tanpa item. Orphan produk pada item slice = 0, harga item <= 0 = 0, gagal cast harga/qty/diskon = 0.
- Diskon item hanya bernilai 0, 1.000, 2.000, dan 5.000; tidak ada nilai yang melebihi subtotal positif. Ini mendukung asumsi diskon nominal per item, tetapi metadata sumber tidak menyatakannya secara eksplisit.
- Harga master produk mempunyai satu baris per product_id, sementara 110/120 baris memiliki `harga_berlaku_dari` setelah 1 Januari 2025. Snapshot ini tidak membuktikan histori harga awal periode; gunakan harga pada item transaksi untuk nilai penjualan.
- Banyak `REFUND` memuat qty positif. Status tersebut belum cukup untuk menghitung nilai retur bersih; laporkan jumlah transaksi REFUND secara terpisah dari nilai item PAID.
- `total_bayar` header sering tidak sama dengan penjumlahan `qty × harga_satuan − diskon` pada item. Karena itu, nilai header tidak boleh disalin ke setiap item; rekonsiliasi menjadi warning desain, bukan persamaan yang diasumsikan benar.
- Satu item mentah tanpa header di seluruh sumber tidak bisa secara pasti dikaitkan ke slice karena tidak ada outlet/tanggal pada item itu sendiri.

## Cara mereproduksi

Jalankan profiling bawaan melalui `.venv/bin/python -m pipeline.profile --topic t2 --slice k9 --json`, lalu jalankan query SQL di atas pada view CSV baca-saja dengan DuckDB di memori. Profil bawaan belum menerapkan filter slice; angka enam test berasal dari query pada dokumen ini.

## Validasi analitik dari CSV (baca-saja)

Angka berikut dihitung dengan kebijakan pada `pipeline/DESIGN_load.md`: buang duplikat header/item yang identik, karantina 4 ID header konflik, dan keluarkan seluruh transaksi PAID yang mempunyai qty negatif. Seluruh keluaran fact di bawah adalah **perkiraan desain berbasis CSV**, bukan hasil menjalankan warehouse.

| Bulan WIB | Nilai item PAID valid (Rp) | ID PAID valid | ID REFUND pada fact | Semua ID pada fact |
|---|---:|---:|---:|---:|
| 2025-01 | 30.193.000 | 398 | 4 | 408 |
| 2025-02 | 27.861.000 | 358 | 5 | 368 |
| 2025-03 | 27.420.000 | 353 | 6 | 370 |
| 2025-04 | 32.294.000 | 429 | 5 | 439 |
| 2025-05 | 33.051.000 | 413 | 1 | 423 |
| 2025-06 | 30.959.000 | 405 | 8 | 420 |
| **Total** | **181.778.000** | **2.356** | **29** | **2.428** |

Produk peringkat pertama menurut nilai item PAID: Januari PRD-0093 (Rp841.000); Februari PRD-0003 (Rp715.000); Maret PRD-0056 (Rp882.000); April PRD-0053 (Rp1.155.000); Mei PRD-0003 (Rp841.000); Juni PRD-0003 (Rp888.000). Jumlah item fact yang diperkirakan: 4.801, terdiri dari 4.656 PAID, 55 REFUND, dan 90 VOID. Angka ini perlu direkonsiliasi ketika implementasi diperbolehkan.

Query reproduksi menggunakan CTE `tx` untuk parse waktu, `slice` untuk filter k9, `canonical_tx` untuk menolak ID konflik, `canonical_item` untuk SELECT DISTINCT item, `invalid_paid` untuk transaksi PAID ber-qty negatif, dan `joined` untuk agregasi. Rumus PAID: `qty * harga_satuan - diskon`. SQL query lengkap dapat dibuat ulang dari definisi tahap 1 pada PLAN; angka di atas bukan hasil query fact.

### SQL reproduksi angka analitik

Kedua query berikut langsung membaca CSV melalui view `raw_transactions` dan `raw_transaction_items` seperti di atas. Mereka hanya digunakan sebagai profiling baca-saja untuk jawaban harapan; belum mengeksekusi SQL fact.

**Tren dan rasio status:**

```sql
WITH tx AS (
    SELECT *, CASE WHEN upper(trim(tanggal_waktu)) LIKE '%Z'
      THEN TRY_CAST(tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta'
      ELSE TRY_CAST(tanggal_waktu AS TIMESTAMP) END AS waktu_wib
    FROM raw_transactions
), slice AS (
    SELECT * FROM tx WHERE outlet_id='OUT-A'
      AND CAST(waktu_wib AS DATE)>=DATE '2025-01-01'
      AND CAST(waktu_wib AS DATE)<DATE '2025-07-01'
), canonical_tx AS (
    SELECT transaction_id, min(waktu_wib) AS waktu_wib,
           upper(trim(min(status))) AS status
    FROM slice GROUP BY 1
    HAVING count(DISTINCT concat_ws('|',coalesce(outlet_id,''),
      coalesce(customer_id,''),coalesce(tanggal_waktu,''),
      coalesce(status,''),coalesce(total_bayar,'')))=1
), canonical_item AS (
    SELECT DISTINCT i.* FROM raw_transaction_items i
    WHERE EXISTS (SELECT 1 FROM canonical_tx t
                  WHERE t.transaction_id=i.transaction_id)
), invalid_paid AS (
    SELECT DISTINCT t.transaction_id FROM canonical_tx t
    JOIN canonical_item i USING(transaction_id)
    WHERE t.status='PAID' AND TRY_CAST(i.qty AS INT)<0
), joined AS (
    SELECT t.transaction_id,t.waktu_wib,t.status,i.item_id,i.product_id,
           TRY_CAST(i.qty AS INT) AS qty,
           TRY_CAST(i.harga_satuan AS INT) AS harga,
           TRY_CAST(i.diskon AS INT) AS diskon
    FROM canonical_tx t JOIN canonical_item i USING(transaction_id)
    WHERE NOT EXISTS (SELECT 1 FROM invalid_paid x
                      WHERE x.transaction_id=t.transaction_id)
)
SELECT strftime(waktu_wib,'%Y-%m') AS bulan,
       sum(CASE WHEN status='PAID' THEN qty*harga-diskon ELSE 0 END) AS nilai_paid_rp,
       count(DISTINCT CASE WHEN status='PAID' THEN transaction_id END) AS tx_paid,
       count(DISTINCT CASE WHEN status='REFUND' THEN transaction_id END) AS tx_refund,
       count(DISTINCT transaction_id) AS tx_tercatat
FROM joined GROUP BY 1 ORDER BY 1;
```

**Produk peringkat pertama per bulan:**

```sql
WITH tx AS (
    SELECT *, CASE WHEN upper(trim(tanggal_waktu)) LIKE '%Z'
      THEN TRY_CAST(tanggal_waktu AS TIMESTAMPTZ) AT TIME ZONE 'Asia/Jakarta'
      ELSE TRY_CAST(tanggal_waktu AS TIMESTAMP) END AS waktu_wib
    FROM raw_transactions
), slice AS (
    SELECT * FROM tx WHERE outlet_id='OUT-A'
      AND CAST(waktu_wib AS DATE)>=DATE '2025-01-01'
      AND CAST(waktu_wib AS DATE)<DATE '2025-07-01'
), canonical_tx AS (
    SELECT transaction_id, min(waktu_wib) AS waktu_wib,
           upper(trim(min(status))) AS status
    FROM slice GROUP BY 1
    HAVING count(DISTINCT concat_ws('|',coalesce(outlet_id,''),
      coalesce(customer_id,''),coalesce(tanggal_waktu,''),
      coalesce(status,''),coalesce(total_bayar,'')))=1
), canonical_item AS (
    SELECT DISTINCT i.* FROM raw_transaction_items i
    WHERE EXISTS (SELECT 1 FROM canonical_tx t
                  WHERE t.transaction_id=i.transaction_id)
), invalid_paid AS (
    SELECT DISTINCT t.transaction_id FROM canonical_tx t
    JOIN canonical_item i USING(transaction_id)
    WHERE t.status='PAID' AND TRY_CAST(i.qty AS INT)<0
), joined AS (
    SELECT t.transaction_id,t.waktu_wib,t.status,i.item_id,i.product_id,
           TRY_CAST(i.qty AS INT) AS qty,
           TRY_CAST(i.harga_satuan AS INT) AS harga,
           TRY_CAST(i.diskon AS INT) AS diskon
    FROM canonical_tx t JOIN canonical_item i USING(transaction_id)
    WHERE NOT EXISTS (SELECT 1 FROM invalid_paid x
                      WHERE x.transaction_id=t.transaction_id)
)
, penjualan_produk AS (
    SELECT strftime(waktu_wib,'%Y-%m') AS bulan,product_id,
           sum(qty*harga-diskon) AS nilai_paid_rp
    FROM joined WHERE status='PAID' GROUP BY 1,2
), peringkat AS (
    SELECT *,dense_rank() OVER(PARTITION BY bulan ORDER BY nilai_paid_rp DESC) AS urutan
    FROM penjualan_produk
)
SELECT bulan,product_id,nilai_paid_rp FROM peringkat WHERE urutan=1 ORDER BY bulan;
```
