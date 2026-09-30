# Kamus metrik UTS — Kelompok 6, T2/k9

## Metrik 1 — Nilai item PAID valid Outlet A

| # | Field | Isi |
|---|---|---|
| 1 | Nama metrik | Nilai item PAID valid Outlet A (`nilai_item_paid_rp`) |
| 2 | Definisi (satu kalimat, tanpa jargon) | Jumlah nilai item pada transaksi Outlet A berstatus PAID yang lolos aturan kualitas selama periode yang dipilih, setelah diskon per item. |
| 3 | Rumus SQL | `SUM(f.nilai_paid_rp)` dengan `nilai_paid_rp = qty_item * harga_satuan_rp - diskon_item_rp` untuk PAID valid dan `0` untuk REFUND/VOID; SQL lengkap: `sql/50_metrics/nilai_item_paid.sql`. |
| 4 | Grain | Dasar: satu `item_id` per transaksi; keluaran SQL: satu tanggal WIB per outlet; total enam bulan adalah SUM tanggal tersebut. |
| 5 | Tabel sumber | `fact_sales_item` + `dim_date` + `dim_outlet`; `outlet_sk` fact berasal dari lookup `outlet_id` header `transactions.csv`, sedangkan nilai item berasal dari `transaction_items.csv`. |
| 6 | Owner (jabatan bernama) | Manajer Outlet A (usulan pemilik keputusan untuk disetujui kelompok). |
| 7 | Time basis | Tanggal transaksi lokal WIB (`Asia/Jakarta`), 1 Januari 2025 inklusif sampai 1 Juli 2025 eksklusif; string `Z` dikonversi dari UTC. |
| 8 | Satuan | Rupiah (Rp), dengan asumsi kerja bahwa `harga_satuan` dan `diskon` pada sumber adalah nominal rupiah. |
| 9 | Dimensi yang boleh dipotong | Tanggal/bulan, produk/kategori, dan pelanggan; outlet hanya `OUT-A` melalui `dim_outlet` sebagai batas cakupan. Setiap fact hanya cocok ke satu versi produk. Jangan SUM harga satuan atau rasio. |
| 10 | Filter default | `outlet_id='OUT-A'`, tanggal WIB `(2025-01-01, 2025-07-01)` dan item fact yang telah lolos validasi; hanya status PAID menyumbang nilai. |
| 11 | Arti nilai kosong | Jika tidak ada baris fact untuk tanggal/outlet, hasil tidak tersedia/NULL (tidak ada data); jika ada baris valid tetapi semuanya VOID/REFUND, hasil 0. Ini bukan bukti outlet tutup. |
| 12 | Versi | v1, berlaku mulai 28 September 2026 untuk desain UTS; perubahan rumus/status harus menaikkan versi. |

**Cara membaca.** Ini adalah nilai penjualan item PAID *tercatat* dengan aturan kualitas yang dinyatakan, bukan laba dan bukan nilai penjualan bersih setelah refund. Data REFUND memiliki qty positif dan negatif tanpa tautan ke transaksi asal; penyesuaian net setelah refund memerlukan aturan tambahan. Untuk sumber k9, profiling baca-saja dengan kebijakan karantina dalam desain memberi perkiraan Rp181.778.000 selama enam bulan. Angka ini bukan hasil menjalankan fact atau loader.

**Asumsi yang harus diputuskan pemilik data.** Diskon diasumsikan rupiah nominal per item karena nilai teramati 0/1.000/2.000/5.000 dan tidak melebihi subtotal item positif; CSV tidak memuat metadata satuannya. Sebelum memakai metrik untuk pelaporan keuangan resmi, konfirmasi satuan diskon dan alasan selisih `total_bayar` header terhadap jumlah item. Jika asumsi salah, revisi rumus dan versi metrik.

### Satu cara gaming

Pada proses load, diskon item PAID dapat diam-diam diubah menjadi nol. Penjualan terlihat lebih besar meskipun jumlah/harga item tidak berubah.

### Guard test yang menangkap gaming

Bandingkan diskon setiap item PAID yang lolos staging dengan nilai yang tersimpan di fact; pelanggaran harus **0** setelah implementasi. Query ini adalah **rancangan guard untuk warehouse masa depan**, bukan salah satu enam test sumber yang memiliki `perkiraan_baris` UTS. `stg_item_valid` berasal dari alur pada `pipeline/DESIGN_load.md`; implementasi harus menyediakan view/table audit yang setara jika staging bersifat sementara.

```sql
SELECT count(*) AS pelanggaran
FROM stg_item_valid s
JOIN stg_transaction_k9 t ON t.transaction_id=s.transaction_id
LEFT JOIN fact_sales_item f ON f.item_id=s.item_id
WHERE upper(trim(t.status))='PAID'
  AND (f.item_id IS NULL
       OR f.diskon_item_rp IS DISTINCT FROM TRY_CAST(s.diskon AS DECIMAL(18,2))
       OR f.nilai_paid_rp IS DISTINCT FROM
          TRY_CAST(s.qty AS DECIMAL(18,2))*TRY_CAST(s.harga_satuan AS DECIMAL(18,2))
          - TRY_CAST(s.diskon AS DECIMAL(18,2)));
```

LEFT JOIN dalam guard juga menangkap item PAID valid yang hilang seluruhnya dari fact. `stg_item_valid` sudah mengecualikan karantina yang sah berdasarkan reason code, sehingga perbandingan memakai populasi yang sama.
