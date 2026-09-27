# DESIGN_load — strategi load (UTS item 2)

> Diisi tim. Tiga hal wajib ada. Kalau ada satu yang kosong, desainnya belum bisa dieksekusi
> orang lain — dan itu kriteria penilaian pertama rubrik.

## Alur: sumber → staging → dim → fact

| # | Tabel | Sumber | Strategi | Kapan menggandakan baris kalau dianggap benar |
|---|---|---|---|---|
| 1 | `dim_date` | generator (diberikan) | `CREATE OR REPLACE` (full) | — tidak bisa: dibangun dari rentang tanggal, bukan dari data |
| 2 | `dim_<entitas>` | TODO | TODO | TODO |
| 3 | `dim_<kategori>` | TODO | TODO | TODO |
| 4 | `fact_<nama>` | TODO | TODO | TODO |

## Tiga pertanyaan wajib

1. **Natural key** yang dipakai untuk upsert/incremental: ______________________
2. **Kolom partisi atau window** kalau incremental (mis. `tanggal`): ____________
3. **Kapan strategi ini menggandakan baris kalau dijalankan dua kali** — nyatakan sendiri:
   ______________________________________________________________________________

## Urutan dependency

Tulis urutan eksekusi yang benar dan alasannya (tabel mana harus ada sebelum yang lain):
______________________________________________________________________________
