# Profil sumber — T1 Kampus — Presensi & Kelulusan / k4

## mahasiswa

`SELECT count(*) AS baris, count(DISTINCT nim) AS nim_unik FROM read_csv_auto('{D}/mahasiswa.csv', all_varchar=true)`

| baris | nim_unik |
|---|---|
| 2700 | 2700 |

## mahasiswa

`SELECT count(*) AS nim_duplikat FROM (SELECT nim FROM read_csv_auto('{D}/mahasiswa.csv', all_varchar=true) GROUP BY 1 HAVING count(*) > 1)`

| nim_duplikat |
|---|
| 0 |

## mahasiswa

`SELECT count(*) FILTER (WHERE angkatan IS NULL OR angkatan='') AS angkatan_kosong, count(DISTINCT status) AS varian_status FROM read_csv_auto('{D}/mahasiswa.csv', all_varchar=true)`

| angkatan_kosong | varian_status |
|---|---|
| 62 | 8 |

## presensi

`SELECT count(*) AS baris, count(*) FILTER (WHERE nim IS NULL) AS nim_null FROM read_csv_auto('{D}/presensi.csv', all_varchar=true)`

| baris | nim_null |
|---|---|
| 117936 | 0 |

## presensi

`SELECT count(*) AS duplikat_grain FROM (SELECT nim, kode_mk, tanggal FROM read_csv_auto('{D}/presensi.csv', all_varchar=true) GROUP BY 1,2,3 HAVING count(*) > 1)`

| duplikat_grain |
|---|
| 4344 |

## presensi

`SELECT count(*) FILTER (WHERE tanggal LIKE '__/__/____') AS tanggal_format_lain, count(DISTINCT status) AS varian_status FROM read_csv_auto('{D}/presensi.csv', all_varchar=true)`

| tanggal_format_lain | varian_status |
|---|---|
| 5812 | 10 |

## nilai

`SELECT count(*) FILTER (WHERE TRY_CAST(nilai_angka AS INT) > 100 OR TRY_CAST(nilai_angka AS INT) < 0) AS nilai_luar_rentang FROM read_csv_auto('{D}/nilai.csv', all_varchar=true)`

| nilai_luar_rentang |
|---|
| 2 |

