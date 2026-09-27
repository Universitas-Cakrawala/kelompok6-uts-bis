# bis-cakrawala-starter — Business Intelligence Systems (SDA2161)

Repo template untuk 9 tim. Satu repo per tim (`Use this template`), semua artefak dikerjakan **di
dalam sesi** dan dibuktikan lewat commit bertanggal sebelum 20:00.

## Setup 5 menit

```bash
pip install -r requirements.txt
python -m pipeline.profile --topic t3 --slice k1      # D1: profil data sebelum transformasi
python -m pipeline.load    --topic t3 --slice k1 --twice   # D3: load 2x, cek row count
python tests/run_tests.py  --topic t3                 # D4: 6 quality test, PASS/FAIL + severity
python checkpoint.py verify --sesi 8                  # DoD UTS (design checkpoint)
```

Semua perintah **offline** — data seed sudah ada di `data/raw/`, tidak ada unduhan saat lab.

## Tiga topik (dataset dari dosen, bukan pilihan sendiri)

| Topik | Folder | Slice |
|---|---|---|
| **T1** Kampus: Presensi & Kelulusan | `data/raw/t1_kampus/` | `--slice k4` (angkatan 2024) · `k5` (2023) · `k7` (2022) |
| **T2** POS UMKM Multi-Outlet | `data/raw/t2_umkm/` | `--slice k8` (outlet A+B+C, 12 bulan) · `k9` (outlet A, 6 bulan, scope −20%) |
| **T3** Cuaca Ekstrem per Desa (BMKG) | `data/raw/t3_publik/<slice>/` | `--slice k1` Kota Bogor · `k2` Kota Semarang · `k3` Kota Makassar · `k6` Kota Denpasar |

## Struktur

```
├── data/raw/            seed (jangan diubah; baca saja)
├── sql/
│   ├── 00_profiling.sql        DIBERIKAN — 6 query profil
│   ├── 10_dim_date.sql         DIBERIKAN — generator dimensi tanggal
│   ├── 20_dim_*.sql            TUGAS tim (D2) — DDL dimensi
│   ├── 30_fact_*.sql           TUGAS tim (D2) — DDL fact
│   ├── 40_analytics/q0N.sql    TUGAS tim (D5 + UTS item 4)
│   ├── 50_metrics/*.sql        TUGAS tim (D6) — satu berkas per metrik
│   └── load.sql                URUTAN EKSEKUSI tim (D3) — loader menolak jalan selama masih TODO
├── pipeline/
│   ├── profile.py       D1 + UTS item 3 (angka untuk test)
│   └── load.py          D3 — idempoten, `--twice`
├── tests/
│   ├── test_definitions.yml    TUGAS tim (D4 + UTS item 3)
│   └── run_tests.py            eksekutor, cetak PASS/FAIL + exit code
├── checkpoint.py        daftar cek DoD per sesi (design & build)
├── docs/                D0, D6, D7, D12 — template terisi contoh
└── warehouse/           hasil kerja: <topik>_<slice>.duckdb + fallback/
```

## Aturan yang dinilai

- **Idempotensi adalah syarat, bukan bonus.** `--twice` harus mencetak row count yang sama. Kalau tim mau membuktikan bahwa `INSERT` polos menggandakan baris, jalankan `--strategy insert_only` — itu contoh yang sengaja salah.
- **Test wajib punya severity.** `blocking` menghentikan load; `warning` hanya memberi tahu. Test tanpa severity diabaikan.
- **`WHERE 1=1` bukan test.** Test harus gagal ketika datanya salah, bukan ketika tabel kosong.
- **Desain dulu (UTS), bangun kemudian (UAS).** `checkpoint.py verify --sesi 8` untuk desain; `--sesi 4|5` untuk artefak build.

## Jalur penyelamat

`warehouse/fallback/<topik>_<slice>.duckdb` adalah warehouse yang **sudah jadi** untuk topikmu —
dipakai **hanya** kalau pipeline tim jebol di tengah sesi dan kamu butuh lanjut ke Sesi 9–10.
Catatan penting:

- **Tidak ada berkas `.sql` acuan di repo ini.** SQL lengkapnya tidak dibagikan; yang ada hanya
  hasil jadinya. Kalau kamu memakai fallback, itu menggantikan artefak D3-mu — katakan terus terang
  ke dosen, jangan mengaku sebagai hasil tim.
- Dosen menanyakan bagian mana pun dari artefak yang kamu kumpulkan. Yang tidak bisa dijelaskan
  bernilai 0 (RPS butir 5), dan fallback ini tidak bisa dijelaskan sebagai kerja tim.
