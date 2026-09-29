-- UTS K6/T2/k9 — Q03: Berapa transaksi REFUND dan rasionya tiap bulan?
-- Keluaran: bulan | transaksi_refund | transaksi_tercatat | rasio_refund_persen.
-- Grain keluaran: satu bulan WIB; denominator adalah ID transaksi valid yang memiliki item di fact.
-- Jawaban harapan: Juni 2025 memiliki 8 transaksi REFUND dari 420 transaksi tercatat, sekitar 1,90%.
-- Bukti: docs/profile_t2_k9_slice.md, bagian validasi analitik; ini rasio status, bukan nilai uang refund.
SELECT strftime(d.full_date, '%Y-%m') AS bulan,
       count(DISTINCT CASE WHEN f.status_transaksi = 'REFUND' THEN f.transaction_id END) AS transaksi_refund,
       count(DISTINCT f.transaction_id) AS transaksi_tercatat,
       round(100.0 * count(DISTINCT CASE WHEN f.status_transaksi = 'REFUND' THEN f.transaction_id END)
             / nullif(count(DISTINCT f.transaction_id), 0), 2) AS rasio_refund_persen
FROM fact_sales_item f
JOIN dim_date d ON d.date_sk = f.date_sk
JOIN dim_outlet o ON o.outlet_sk = f.outlet_sk
WHERE o.outlet_id = 'OUT-A'
  AND d.full_date >= DATE '2025-01-01' AND d.full_date < DATE '2025-07-01'
GROUP BY 1
ORDER BY 1;
