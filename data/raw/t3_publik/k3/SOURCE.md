# SOURCE — T3 Cuaca BMKG (k3)

- **Sumber 1:** `https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4={kode desa}` — prakiraan cuaca BMKG, tanpa API key.
- **Sumber 2:** `https://wilayah.id/api` — master wilayah kode BPS 4 level (provinsi/kab/kec/desa).
- **Snapshot ditarik:** 2026-09-19T15:28:57Z
- **Slice:** Sulawesi Selatan — Kota Makassar (73.71)
- **Cakupan:** 153 desa diminta, 2874 baris slot, 0 desa gagal.
- **Catatan:** BMKG hanya menerbitkan prakiraan (bukan arsip historis). Repo membekukan snapshot ini;
  jangan tarik ulang saat lab. Tarik ulang hanya saat persiapan, lalu commit ulang berkasnya.

## Desa yang tidak punya prakiraan
- (tidak ada)
