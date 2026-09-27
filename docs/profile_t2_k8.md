# Profil sumber — T2 POS UMKM — Multi-Outlet / k8

## transactions

`SELECT count(*) AS baris, count(DISTINCT transaction_id) AS id_unik FROM read_csv_auto('{D}/transactions.csv', all_varchar=true)`

| baris | id_unik |
|---|---|
| 15892 | 15671 |

## transactions

`SELECT count(*) AS id_duplikat FROM (SELECT transaction_id FROM read_csv_auto('{D}/transactions.csv', all_varchar=true) GROUP BY 1 HAVING count(*) > 1)`

| id_duplikat |
|---|
| 219 |

## transactions

`SELECT count(*) FILTER (WHERE tanggal_waktu LIKE '%Z') AS timestamp_utc, count(DISTINCT status) AS varian_status FROM read_csv_auto('{D}/transactions.csv', all_varchar=true)`

| timestamp_utc | varian_status |
|---|---|
| 2389 | 5 |

## transactions

`SELECT count(*) AS tanpa_item FROM read_csv_auto('{D}/transactions.csv', all_varchar=true) t WHERE NOT EXISTS (SELECT 1 FROM read_csv_auto('{D}/transaction_items.csv', all_varchar=true) i WHERE i.transaction_id = t.transaction_id)`

| tanpa_item |
|---|
| 158 |

## transaction_items

`SELECT count(*) FILTER (WHERE TRY_CAST(qty AS INT) < 0) AS qty_negatif, count(*) AS baris FROM read_csv_auto('{D}/transaction_items.csv', all_varchar=true)`

| qty_negatif | baris |
|---|---|
| 628 | 31343 |

## transaction_items

`SELECT count(*) AS fk_orphan FROM read_csv_auto('{D}/transaction_items.csv', all_varchar=true) i WHERE NOT EXISTS (SELECT 1 FROM read_csv_auto('{D}/products.csv', all_varchar=true) p WHERE p.product_id = i.product_id)`

| fk_orphan |
|---|
| 1 |

## products

`SELECT count(DISTINCT harga_satuan) AS varian_harga, count(*) AS produk FROM read_csv_auto('{D}/products.csv', all_varchar=true)`

| varian_harga | produk |
|---|---|
| 9 | 120 |

