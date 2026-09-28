# D7 — Batas lingkup capstone Kelompok 6

> **Draf untuk disepakati kelompok sebelum defense Sesi 8.** Dosen mengonfirmasi form D7 cukup diisi dan dibaca, tanpa tanda tangan dan tanpa dimasukkan ke PDF pengumpulan. Isi yang bertanda “usulan/menunggu” belum boleh diklaim sebagai kesepakatan kelompok. Form ini menjadi acuan scope pembangunan sesudah UTS; dashboard tidak dibangun saat UTS.

Tim: **Kelompok 6**

Topik/slice: **T2 POS UMKM / k9 — Outlet A, Januari–Juni 2025 (scope −20%)**

Tanggal draf: **28 September 2026**

Anggota dan NIM:

| Anggota | NIM |
|---|---|
| Titanio Yudista | 24120500031 |
| Taufiqurrahman | 24130500005 |
| Zaki Khabibi Ziwab | 24130500009 |
| Wildan Rizky Wijaya | 24110500029 |

## AKAN DIBANGUN (maksimal 1 fact table + 1 conformed dimension per RPS butir 8)

| # | Artefak | Ukuran selesai | Deadline |
|---|---|---|---|
| 1 | `fact_sales_item` untuk `OUT-A`, tanggal WIB 2025-01-01 s.d. 2025-06-30 | Satu baris per `item_id` valid, tanpa duplikat, FK terisi, jumlah/nominal lolos rekonsiliasi yang disepakati. | **Menunggu jadwal kelompok** |
| 2 | `dim_date` sebagai conformed dimension | Setiap fact punya tepat satu `date_sk` yang cocok; tanggal WIB dan rentang kalender terdokumentasi. Dimensi produk, outlet, dan customer mendukung fact sesuai desain star; `outlet_sk` fact merujuk `OUT-A` pada `dim_outlet`. | **Menunggu jadwal kelompok** |
| 3 | Metrik di kamus: **usulan 2 dari 3** menuju UAS | Satu metrik UTS (`nilai_item_paid_rp`) sudah didefinisikan lengkap; metrik kedua dan target akhir hanya ditetapkan setelah kelompok sepakat. | **Menunggu keputusan/jadwal kelompok** |
| 4 | Dashboard: **usulan 3 tile** menuju UAS | Tile tren bulanan, kontribusi produk, dan rasio status REFUND berdasarkan metrik/SQL yang disetujui; belum dibuat pada UTS. | **Menunggu keputusan/jadwal kelompok** |

**Catatan dimensi:** koreksi terbaru dosen menetapkan tiga dimensi domain (`dim_product`, `dim_outlet`, `dim_customer`) ditambah `dim_date`, sehingga total empat tabel dimensi. Fact memakai `outlet_sk` untuk `OUT-A`.

## TIDAK LAGI DIBANGUN (sebut namanya, jangan “kalau ada waktu”)

| # | Yang dicabut | Alasan |
|---|---|---|
| 1 | Analisis Outlet B/C dan perbandingan antar-outlet | Penugasan k9 membatasi cakupan ke Outlet A; memasukkan outlet lain menukar slice. |
| 2 | Analisis periode Juli–Desember 2025 dan tahun penuh | Slice k9 hanya Januari–Juni 2025. |
| 3 | Metrik laba bersih per produk | Data HPP historis dan biaya operasional tidak ada di dataset yang diberikan. |

Dosen mengonfirmasi batas k9 (Outlet A selama enam bulan) sudah memenuhi scope −20%; pemotongan fitur tambahan tidak diwajibkan. Tujuh deliverable UTS tetap lengkap.

## Kesepakatan kelompok dan pembacaan dosen

- Target **2 dari 3 metrik**, **3 tile**, dan seluruh deadline pada tabel masih **usulan** sampai disepakati kelompok.
- Sesuai jawaban lisan dosen yang dicatat kelompok, D7 tidak memerlukan tanda tangan dan tidak perlu disertakan dalam PDF. Dosen cukup membaca berkas ini dari repo.
- Setelah kelompok menyepakati target dan jadwal, ganti setiap placeholder dengan keputusan nyata serta catat tanggal persetujuannya di sini.
