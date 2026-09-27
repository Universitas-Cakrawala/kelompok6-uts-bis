# data/raw/ — seed (jangan diubah)

Diisi dosen, dibaca saja. Salin dari folder seed kelas:

```bash
cp -R <seed-kelas>/t1_kampus  data/raw/
cp -R <seed-kelas>/t2_umkm    data/raw/
cp -R <seed-kelas>/t3_publik  data/raw/
```

T3 hanya butuh foldernya sendiri (tiap slice ada di dalam `t3_publik/<kode-tim>/`), dan setiap
folder T3 menyertakan `SOURCE.md` — sumber, tanggal snapshot, jumlah baris. Itu syarat data publik:
tanpa SOURCE.md, angkanya tidak bisa diperiksa siapa pun.
