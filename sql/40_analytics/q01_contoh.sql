-- ============================================================
-- CONTOH (diberikan) — T3: desa mana yang masuk siaga, dan berapa slot-nya
-- Pola yang sama dipakai untuk topik lain. Perhatikan: ada WHERE yang mencerminkan slice tim.
-- ============================================================

-- Jawaban yang diharapkan (tulis ini di Brief, bukan hanya SQL-nya):
--   "Dalam 3 hari ke depan, X desa di K kecamatan masuk status siaga; sisanya tidak."
-- Kolom keluaran: kecamatan | desa | slot_siaga | slot_total | rasio

SELECT w.kecamatan,
       w.desa,
       sum(f.is_siaga)                       AS slot_siaga,
       count(*)                              AS slot_total,
       round(sum(f.is_siaga)::DOUBLE / count(*), 2) AS rasio_siaga
FROM fact_prakiraan_cuaca f
JOIN dim_wilayah w USING (wilayah_sk)
GROUP BY 1, 2
HAVING sum(f.is_siaga) > 0
ORDER BY 3 DESC, 5 DESC;
