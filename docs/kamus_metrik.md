# D6 — Kamus metrik (12 field)

> UTS item 5 menilai **satu** metrik lengkap; UAS menilai tiga. Setiap metrik wajib punya berkas SQL
> di `sql/50_metrics/` — definisi yang tidak bisa dijalankan belum tentu benar.

## Metrik 1 — ______________________

| # | Field | Isi |
|---|---|---|
| 1 | Nama metrik |  |
| 2 | Definisi (satu kalimat, tanpa jargon) |  |
| 3 | Rumus (SQL-nya, bukan bahasa manusia) |  |
| 4 | Grain |  |
| 5 | Tabel sumber |  |
| 6 | Owner (jabatan bernama) |  |
| 7 | Time basis | per hari kalender WIB / per bulan / … |
| 8 | Satuan |  |
| 9 | Dimensi yang boleh dipotong |  |
| 10 | Filter default |  |
| 11 | Arti nilai kosong | 0 / tidak ada data / tidak dihitung — pilih satu |
| 12 | Versi | v1, tanggal berlaku |

### Cara metrik ini di-gaming
Tulis satu cara orang bisa membuat metrik ini terlihat bagus tanpa benar-benar membaik:
______________________________________________________________________________

### Guard test-nya
Satu test yang menangkap cara itu:
______________________________________________________________________________
