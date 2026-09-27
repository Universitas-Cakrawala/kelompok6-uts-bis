# SOURCE — T3 Cuaca BMKG (k2)

- **Sumber 1:** `https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4={kode desa}` — prakiraan cuaca BMKG, tanpa API key.
- **Sumber 2:** `https://wilayah.id/api` — master wilayah kode BPS 4 level (provinsi/kab/kec/desa).
- **Snapshot ditarik:** 2026-09-19T15:24:25Z
- **Slice:** Jawa Tengah — Kota Semarang (33.74)
- **Cakupan:** 177 desa diminta, 3009 baris slot, 0 desa gagal.
- **Catatan:** BMKG hanya menerbitkan prakiraan (bukan arsip historis). Repo membekukan snapshot ini;
  jangan tarik ulang saat lab. Tarik ulang hanya saat persiapan, lalu commit ulang berkasnya.

## Desa yang tidak punya prakiraan
- (tidak ada)
