-- UTS K6/T2/k9 — Definisi eksekutabel metrik pada docs/kamus_metrik.md.
-- Grain keluaran: hari kalender WIB, OUT-A. Fact hanya memuat item transaksi valid.
-- REFUND/VOID tidak menambah nilai_paid_rp; metrik ini bukan laba dan bukan net setelah refund.
SELECT d.full_date AS tanggal_wib,
       o.outlet_id,
       sum(f.nilai_paid_rp) AS nilai_item_paid_rp,
       count(DISTINCT CASE WHEN f.status_transaksi='PAID' THEN f.transaction_id END) AS transaksi_paid
FROM fact_sales_item f
JOIN dim_date d ON d.date_sk=f.date_sk
JOIN dim_outlet o ON o.outlet_sk=f.outlet_sk
WHERE o.outlet_id='OUT-A'
  AND d.full_date>=DATE '2025-01-01' AND d.full_date<DATE '2025-07-01'
GROUP BY 1,2
ORDER BY 1;
