-- ============================================================
-- TUGAS TIM (D2 / UTS item 1.1, 1.2, 1.4) — fact table
-- Satu fact saja. Grain ditulis lengkap di komentar, bukan singkatan.
-- ============================================================

-- GRAIN: Satu baris = ______________________________________________.
--        (contoh bentuk benar: "satu desa pada satu slot prakiraan")
--
-- Setiap measure diberi label aditivitas + alasan:
--   ADDITIVE      : boleh di-SUM lintas semua dimensi  (contoh: qty, curah hujan mm)
--   SEMI-ADDITIVE : boleh di-SUM di sebagian dimensi   (contoh: saldo stok, flag siaga per waktu)
--   NON-ADDITIVE  : jangan di-SUM, pakai min/max/avg   (contoh: harga, suhu, persentase)

-- TODO: tulis DDL fact + JOIN ke setiap dimensi (satu JOIN per dimensi — star, bukan snowflake).
-- Kolom yang WAJIB ada:
--   * satu surrogate key per dimensi (<entitas>_sk), bukan ID bisnis
--   * ID bisnis yang tidak punya dimensi sendiri (nomor transaksi) tetap di fact, diberi label
--     "degenerate"
--   * measure dengan label aditivitas di komentar
