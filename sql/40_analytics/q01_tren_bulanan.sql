-- UTS K6/T2/k9 — Q01: Berapa nilai item PAID valid dan transaksi PAID per bulan?
-- Keluaran: bulan | nilai_paid_rp | transaksi_paid.
-- Grain keluaran: satu bulan kalender WIB untuk OUT-A, Januari–Juni 2025.
-- Jawaban harapan: Mei 2025 tertinggi dengan Rp33.051.000 dari 413 transaksi PAID valid.
-- Bukti: docs/profile_t2_k9_slice.md, bagian validasi analitik; query fact ini belum dijalankan.
-- Bulan tanpa baris fact menghasilkan NULL; bulan dengan fact hanya REFUND/VOID menghasilkan 0.
WITH bulan AS (
    SELECT strftime(d, '%Y-%m') AS bulan
    FROM unnest(generate_series(DATE '2025-01-01', DATE '2025-06-01', INTERVAL 1 MONTH)) AS x(d)
), agregat AS (
    SELECT strftime(d.full_date, '%Y-%m') AS bulan,
           sum(f.nilai_paid_rp) AS nilai_paid_rp,
           count(DISTINCT CASE WHEN f.status_transaksi = 'PAID' THEN f.transaction_id END) AS transaksi_paid
    FROM fact_sales_item f
    JOIN dim_date d ON d.date_sk = f.date_sk
    JOIN dim_outlet o ON o.outlet_sk = f.outlet_sk
    WHERE o.outlet_id = 'OUT-A'
      AND d.full_date >= DATE '2025-01-01' AND d.full_date < DATE '2025-07-01'
    GROUP BY 1
)
SELECT b.bulan, a.nilai_paid_rp, a.transaksi_paid
FROM bulan b LEFT JOIN agregat a USING (bulan)
ORDER BY b.bulan;
