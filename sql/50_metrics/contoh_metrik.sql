-- ============================================================
-- TUGAS TIM (D6 / UTS item 5) — satu berkas SQL per metrik di kamus.
-- Metrik tanpa SQL = definisi yang belum bisa dibuktikan.
-- ============================================================

-- Contoh T3: "jumlah desa siaga per hari"
-- Kamus 12 field-nya ada di docs/kamus_metrik.md — SQL ini harus cocok dengan rumusnya.
SELECT d.full_date AS tanggal, count(DISTINCT f.wilayah_sk) AS desa_siaga
FROM fact_prakiraan_cuaca f JOIN dim_date d USING (date_sk)
WHERE f.is_siaga = 1
GROUP BY 1 ORDER BY 1;
