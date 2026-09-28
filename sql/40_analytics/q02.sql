-- UTS K6/T2/k9 — Q02: Produk apa yang paling besar kontribusi nilai PAID tiap bulan?
-- Keluaran: bulan | product_id | nama_produk_tercatat | nilai_paid_rp | peringkat.
-- Grain keluaran: satu identitas produk per bulan WIB; versi SCD digabung menurut product_id.
-- Jawaban harapan: PRD-0003 memimpin pada Februari, Mei, dan Juni 2025 setelah aturan kualitas diterapkan.
-- Bukti: docs/profile_t2_k9_slice.md, bagian validasi analitik; query fact ini belum dijalankan.
WITH penjualan_produk AS (
    SELECT strftime(d.full_date, '%Y-%m') AS bulan,
           p.product_id,
           arg_max(p.nama_produk, p.valid_from) AS nama_produk_tercatat,
           sum(f.nilai_paid_rp) AS nilai_paid_rp
    FROM fact_sales_item f
    JOIN dim_date d ON d.date_sk = f.date_sk
    JOIN dim_outlet o ON o.outlet_sk = f.outlet_sk
    JOIN dim_product p ON p.product_sk = f.product_sk
    WHERE o.outlet_id = 'OUT-A'
      AND d.full_date >= DATE '2025-01-01' AND d.full_date < DATE '2025-07-01'
      AND f.status_transaksi = 'PAID'
    GROUP BY 1, 2
), peringkat_produk AS (
    SELECT *, dense_rank() OVER (PARTITION BY bulan ORDER BY nilai_paid_rp DESC) AS peringkat
    FROM penjualan_produk
)
SELECT bulan, product_id, nama_produk_tercatat, nilai_paid_rp, peringkat
FROM peringkat_produk
WHERE peringkat <= 3
ORDER BY bulan, peringkat, product_id;
