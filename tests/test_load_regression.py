"""Regresi loader pada salinan CSV sementara dan DuckDB di memori.

Jalankan: .venv/bin/python -m unittest discover -s tests -p test_load_regression.py
Tidak menulis data/raw atau warehouse proyek.
"""
import csv
from decimal import Decimal
from pathlib import Path
import shutil
import tempfile
import unittest

import duckdb

from pipeline import config
from pipeline.load import render, statements, run_once


ROOT = Path(__file__).resolve().parents[1]


class LoadRegression(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="k6-load-")
        self.source = Path(self.tmp.name) / "source"
        shutil.copytree(ROOT / "data/raw/t2_umkm", self.source)
        self.con = duckdb.connect()
        self.load()

    def tearDown(self):
        self.con.close()
        self.tmp.cleanup()

    def load(self, day="2026-10-02", topic="t2", slice_id="k9"):
        ctx = {"dir": str(self.source), "topic": topic, "slice": slice_id,
               "cfg": config.TOPICS[topic]}
        sql = render((ROOT / "sql/load.sql").read_text(), ctx)
        sql = sql.replace("current_date", f"DATE '{day}'")
        run_once(self.con, statements(sql), "full", True)

    def rows(self, file):
        with (self.source / file).open(newline="") as stream:
            return list(csv.DictReader(stream))

    def write(self, file, rows):
        with (self.source / file).open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)

    def state(self):
        return {name: self.con.execute(f"SELECT * FROM {name} ORDER BY 1").fetchall()
                for name in ("dim_product", "dim_customer", "dim_outlet", "fact_sales_item")}

    def test_same_snapshot_and_guard(self):
        before = self.state()
        self.load()
        self.assertEqual(before, self.state())
        self.assertEqual(self.con.execute("SELECT count(*),sum(nilai_paid_rp) FROM fact_sales_item").fetchone(),
                         (4801, Decimal("181778000.00")))
        guard = (ROOT / "docs/kamus_metrik.md").read_text().split("```sql\n", 1)[1].split("```", 1)[0]
        self.assertEqual(self.con.execute(guard).fetchone()[0], 0)
        self.assertTrue(self.con.execute("SELECT count(*) FROM duckdb_constraints() WHERE table_name='fact_sales_item'").fetchone()[0])

    def test_new_master_ids_keep_existing_keys(self):
        before = {name: self.con.execute(f"SELECT {name}_id,{name}_sk FROM dim_{name}").fetchall()
                  for name in ("product", "outlet", "customer")}
        for name, file in (("product", "products.csv"), ("outlet", "outlets.csv"), ("customer", "customers.csv")):
            rows = self.rows(file)
            new = dict(rows[0])
            new[name + "_id"] = "000-NEW"
            rows.append(new)
            self.write(file, rows)
        self.load()
        for name, values in before.items():
            actual = dict(self.con.execute(f"SELECT {name}_id,{name}_sk FROM dim_{name}").fetchall())
            for key, sk in values:
                self.assertEqual(actual[key], sk)

    def test_product_history_and_same_day_rejection(self):
        rows = self.rows("products.csv")
        pid = rows[0]["product_id"]
        old_sk = self.con.execute("SELECT product_sk FROM dim_product WHERE product_id=?", [pid]).fetchone()[0]
        rows[0]["nama_produk"] = "Nama baru"
        self.write("products.csv", rows)
        self.load()
        versions = self.con.execute("SELECT product_sk,is_current FROM dim_product WHERE product_id=? ORDER BY valid_from", [pid]).fetchall()
        self.assertEqual(len(versions), 2)
        self.assertEqual(versions[0], (old_sk, False))
        self.assertTrue(versions[1][1])
        self.assertEqual(self.con.execute("SELECT count(*) FROM fact_sales_item f JOIN dim_product p USING(product_sk) WHERE p.product_id=? AND f.product_sk<>?", [pid, old_sk]).fetchone()[0], 0)
        before = self.state()
        self.load()
        self.assertEqual(before, self.state())
        rows[0]["nama_produk"] = "Nama berubah lagi"
        self.write("products.csv", rows)
        with self.assertRaisesRegex(duckdb.Error, "hari yang sama"):
            self.load()
        self.assertEqual(before, self.state())
        self.load(day="2026-10-03")
        self.assertEqual(self.con.execute("SELECT count(*) FROM dim_product WHERE product_id=?", [pid]).fetchone()[0], 3)

    def test_type1_update_preserves_keys(self):
        for name, file, attribute in (("outlet", "outlets.csv", "nama_outlet"), ("customer", "customers.csv", "nama_pelanggan")):
            rows = self.rows(file)
            key = rows[0][name + "_id"]
            old_sk = self.con.execute(f"SELECT {name}_sk FROM dim_{name} WHERE {name}_id=?", [key]).fetchone()[0]
            rows[0][attribute] = "Koreksi atribut"
            self.write(file, rows)
            self.load()
            self.assertEqual(self.con.execute(f"SELECT {name}_sk,{attribute} FROM dim_{name} WHERE {name}_id=?", [key]).fetchone(), (old_sk, "Koreksi atribut"))

    def test_invalid_qty_subtotal_and_empty_item_are_quarantined(self):
        items = self.rows("transaction_items.csv")
        for field, value in (("qty", "0"), ("diskon", "999999999"), ("item_id", "")):
            item, tx = self.con.execute("SELECT item_id,transaction_id FROM fact_sales_item WHERE status_transaksi='PAID' ORDER BY item_id LIMIT 1").fetchone()
            for row in items:
                if row["item_id"] == item:
                    row[field] = value
            self.write("transaction_items.csv", items)
            self.load()
            self.assertEqual(self.con.execute("SELECT count(*) FROM fact_sales_item WHERE item_id=?", [item]).fetchone()[0], 0)
            self.assertGreater(self.con.execute("SELECT count(*) FROM stg_quarantine WHERE severity='blocking'").fetchone()[0], 0)
            if field != "item_id":
                self.assertEqual(self.con.execute("SELECT count(*) FROM fact_sales_item WHERE transaction_id=?", [tx]).fetchone()[0], 0)

    def test_conflicting_master_rolls_back(self):
        before = self.state()
        rows = self.rows("outlets.csv")
        duplicate = dict(rows[0])
        duplicate["nama_outlet"] = "Konflik"
        rows.append(duplicate)
        self.write("outlets.csv", rows)
        with self.assertRaisesRegex(duckdb.Error, "Master kosong/ambigu"):
            self.load()
        self.assertEqual(before, self.state())
        self.assertEqual(self.con.execute("SELECT count(*) FROM stg_outlets").fetchone()[0], 4)

    def test_cross_slice_header_conflict(self):
        before_count = self.con.execute("SELECT count(*) FROM fact_sales_item").fetchone()[0]
        tx = self.con.execute("SELECT transaction_id FROM fact_sales_item ORDER BY item_id LIMIT 1").fetchone()[0]
        rows = self.rows("transactions.csv")
        duplicate = dict(next(r for r in rows if r["transaction_id"] == tx))
        duplicate["outlet_id"] = "OUT-B"
        rows.append(duplicate)
        self.write("transactions.csv", rows)
        self.load()
        self.assertEqual(self.con.execute("SELECT count(*) FROM fact_sales_item WHERE transaction_id=?", [tx]).fetchone()[0], 0)
        self.assertLess(self.con.execute("SELECT count(*) FROM fact_sales_item").fetchone()[0], before_count)

    def test_fact_correction_delete_and_protected_scope(self):
        item = self.con.execute("SELECT item_id FROM fact_sales_item WHERE status_transaksi='PAID' ORDER BY item_id LIMIT 1").fetchone()[0]
        items = self.rows("transaction_items.csv")
        for row in items:
            if row["item_id"] == item:
                row["harga_satuan"] = "99999"
        self.write("transaction_items.csv", items)
        self.load()
        self.assertEqual(self.con.execute("SELECT harga_satuan_rp FROM fact_sales_item WHERE item_id=?", [item]).fetchone()[0], Decimal("99999"))
        self.con.execute("INSERT INTO fact_sales_item SELECT 'OUTSIDE','OUTSIDE',outlet_sk,20250701,product_sk,customer_sk,TIMESTAMP '2025-07-01',status_transaksi,qty_item,harga_satuan_rp,diskon_item_rp,qty_paid,nilai_paid_rp FROM fact_sales_item LIMIT 1")
        items = [row for row in items if row["item_id"] != item]
        self.write("transaction_items.csv", items)
        self.load()
        self.assertEqual(self.con.execute("SELECT count(*) FROM fact_sales_item WHERE item_id=?", [item]).fetchone()[0], 0)
        self.assertEqual(self.con.execute("SELECT count(*) FROM fact_sales_item WHERE item_id='OUTSIDE'").fetchone()[0], 1)

    def test_wrong_slice_rolls_back(self):
        before = self.state()
        with self.assertRaisesRegex(duckdb.Error, "hanya mendukung"):
            self.load(slice_id="k8")
        self.assertEqual(before, self.state())

    def test_late_failure_rolls_back_dimension_updates(self):
        item, tx = self.con.execute("SELECT item_id,transaction_id FROM fact_sales_item WHERE status_transaksi='PAID' ORDER BY item_id LIMIT 1").fetchone()
        self.con.execute("INSERT INTO fact_sales_item SELECT 'PROTECTED','PROTECTED',outlet_sk,20250701,product_sk,customer_sk,TIMESTAMP '2025-07-01',status_transaksi,qty_item,harga_satuan_rp,diskon_item_rp,qty_paid,nilai_paid_rp FROM fact_sales_item WHERE item_id=?", [item])
        before = self.state()
        outlets = self.rows("outlets.csv")
        outlets[0]["nama_outlet"] = "Perubahan yang harus rollback"
        self.write("outlets.csv", outlets)
        items = self.rows("transaction_items.csv")
        new = dict(next(row for row in items if row["item_id"] == item))
        new["item_id"] = "PROTECTED"
        items.append(new)
        self.write("transaction_items.csv", items)
        with self.assertRaisesRegex(duckdb.Error, "di luar k9"):
            self.load()
        self.assertEqual(before, self.state())


if __name__ == "__main__":
    unittest.main()
