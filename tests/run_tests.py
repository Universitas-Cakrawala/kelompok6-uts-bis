"""D4 / UTS item 3 — eksekutor test kualitas data.

Test hidup di `tests/test_definitions.yml`. Tiap test punya severity:
  blocking  → datanya tidak boleh masuk warehouse
  warning   → boleh masuk, tapi harus ada yang tahu

`expected` menyatakan hasil yang **diharapkan**: `fail` berarti test ini memang menangkap
masalah yang sudah kamu lihat di profil. Test yang selalu pass di data yang jelas kotor
adalah test palsu — paling sering bentuknya `WHERE 1=1`.

Pakai:
    python tests/run_tests.py --topic t2 --slice k8
    python tests/run_tests.py --topic t3 --slice k1 --json
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import duckdb
import yaml

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from pipeline import config  # noqa: E402

SEVERITY = ("blocking", "warning")


def view_name(berkas: str) -> str:
    return "raw_" + os.path.splitext(os.path.basename(berkas))[0]


def prepare(con: duckdb.DuckDBPyConnection, ctx: dict) -> list[str]:
    """Semua CSV slice jadi view `raw_<nama>`, dan warehouse (kalau ada) jadi skema `wh`."""
    view = []
    for berkas in sorted(os.listdir(ctx["dir"])):
        if berkas.endswith(".csv"):
            path = os.path.join(ctx["dir"], berkas)
            con.execute(f"CREATE OR REPLACE VIEW {view_name(berkas)} AS SELECT * FROM read_csv_auto('{path}', all_varchar=true)")
            view.append(view_name(berkas))
    db = config.db_path(ctx["topic"], ctx["slice"])
    if os.path.exists(db):
        con.execute(f"ATTACH '{db}' AS wh (READ_ONLY)")
    return view


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--topic", required=True, choices=sorted(config.TOPICS))
    ap.add_argument("--slice", required=True)
    ap.add_argument("--file", default=os.path.join(config.ROOT, "tests", "test_definitions.yml"))
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    ctx = config.resolve(args.topic, args.slice)
    con = duckdb.connect()
    views = prepare(con, ctx)
    semua = yaml.safe_load(open(args.file, encoding="utf-8"))["tests"]
    tests = [t for t in semua if t["topic"] == args.topic]

    hasil, gagal_blocking = [], 0
    for t in tests:
        sev = t.get("severity", "").strip()
        if sev not in SEVERITY:
            hasil.append({**t, "hasil": "DITOLAK", "catatan": "severity tidak dikenal → test diabaikan"})
            continue
        if "wh." in t["sql"] and "wh" not in views and "ATTACH" not in " ".join(con.execute("SELECT 1").fetchall().__str__()):
            hasil.append({**t, "hasil": "SKIP", "catatan": "butuh warehouse (jalankan pipeline.load dulu)"})
            continue
        try:
            pelanggaran = con.execute(t["sql"]).fetchone()[0]
        except Exception as exc:  # SQL salah = test belum jadi
            hasil.append({**t, "hasil": "ERROR", "catatan": str(exc).split("\n")[0][:110]})
            continue
        aktual = "fail" if pelanggaran > 0 else "pass"
        cocok = aktual == t.get("expected")
        hasil.append({**t, "pelanggaran": pelanggaran, "hasil": "PASS" if aktual == "pass" else "FAIL",
                      "sesuai_harapan": cocok})
        if sev == "blocking" and not cocok:
            gagal_blocking += 1

    if args.json:
        print(json.dumps(hasil, indent=2, ensure_ascii=False))
        return

    print(f"# Test kualitas — {ctx['cfg']['label']} / {args.slice}")
    print(f"# {len(tests)} test · view: {', '.join(views)}\n")
    for h in hasil:
        tanda = {"PASS": "✓", "FAIL": "✗"}.get(h["hasil"], "•")
        harap = h.get("expected", "?")
        angka = f"{h.get('pelanggaran'):,}" if isinstance(h.get("pelanggaran"), int) else "-"
        sesuai = {True: "sesuai harapan", False: "TIDAK sesuai harapan"}.get(h.get("sesuai_harapan"), "")
        print(f"{tanda} [{h['severity']:<8}] {h['name']:<32} pelanggaran={angka:<8} expected={harap:<5} {sesuai}")
        if h.get("catatan"):
            print(f"      catatan: {h['catatan']}")
    jumlah_fail = sum(1 for h in hasil if h["hasil"] == "FAIL")
    print(f"\n{jumlah_fail} test menangkap masalah · {gagal_blocking} blocking tidak sesuai harapan")
    if jumlah_fail == 0 and not args.json:
        print("PERINGATAN: tidak ada satu pun test yang gagal. Di data ini itu mencurigakan —")
        print("           cek apakah test-mu benar-benar bisa gagal (bukan WHERE 1=1).")
    sys.exit(1 if gagal_blocking else 0)


if __name__ == "__main__":
    main()
