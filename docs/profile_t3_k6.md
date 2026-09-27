# Profil sumber — T3 Cuaca Ekstrem per Desa (BMKG) / k6

## prakiraan_cuaca

`SELECT count(*) AS baris, count(DISTINCT adm4) AS desa FROM read_csv_auto('{D}/prakiraan_cuaca.csv', all_varchar=true)`

| baris | desa |
|---|---|
| 774 | 43 |

## prakiraan_cuaca

`SELECT count(*) FILTER (WHERE vs IS NULL OR vs = '') AS vs_kosong FROM read_csv_auto('{D}/prakiraan_cuaca.csv', all_varchar=true)`

| vs_kosong |
|---|
| 774 |

## prakiraan_cuaca

`SELECT count(*) FILTER (WHERE TRY_CAST(tp AS DOUBLE) = 0) AS tp_nol, count(*) AS baris FROM read_csv_auto('{D}/prakiraan_cuaca.csv', all_varchar=true)`

| tp_nol | baris |
|---|---|
| 774 | 774 |

## prakiraan_cuaca

`SELECT weather AS kode, weather_desc AS deskripsi, count(*) AS baris FROM read_csv_auto('{D}/prakiraan_cuaca.csv', all_varchar=true) GROUP BY 1,2 ORDER BY 3 DESC`

| kode | deskripsi | baris |
|---|---|---|
| 1 | Cerah | 528 |
| 0 | Cerah | 162 |
| 2 | Cerah Berawan | 84 |

## prakiraan_cuaca

`SELECT min(TRY_CAST(time_index AS VARCHAR)) AS time_index_contoh, count(DISTINCT analysis_date) AS analysis_date_unik FROM read_csv_auto('{D}/prakiraan_cuaca.csv', all_varchar=true)`

| time_index_contoh | analysis_date_unik |
|---|---|
| 11-12 | 1 |

## prakiraan_cuaca

`SELECT count(*) FILTER (WHERE epoch(strptime(local_datetime, '%Y-%m-%d %H:%M:%S')) - epoch(strptime(utc_datetime, '%Y-%m-%d %H:%M:%S')) = 25200) AS baris_selisih_7jam, count(*) AS baris FROM read_csv_auto('{D}/prakiraan_cuaca.csv', all_varchar=true)`

| baris_selisih_7jam | baris |
|---|---|
| 0 | 774 |

## desa

`SELECT count(*) AS desa, count(DISTINCT kecamatan) AS kecamatan FROM read_csv_auto('{D}/desa.csv', all_varchar=true)`

| desa | kecamatan |
|---|---|
| 43 | 4 |

