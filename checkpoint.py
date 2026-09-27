"""checkpoint.py — daftar cek DoD per sesi, dijalankan mahasiswa SEBELUM keluar ruangan,
dan dijalankan dosen dengan perintah yang sama persis saat menilai.

    python checkpoint.py verify --sesi 8                    # UTS: design checkpoint (semua topik)
    python checkpoint.py verify --sesi 5 --topic t2         # D4: test kualitas
    python checkpoint.py verify --sesi 4 --topic t2 --slice k8   # D3: load idempoten

Exit code 0 = semua syarat wajib terpenuhi. 1 = ada yang belum.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pipeline import config  # noqa: E402

OK, NO, WARN = "\033[32m✓\033[0m", "\033[31m✗\033[0m", "\033[33m•\033[0m"


def baca(path: str) -> str:
    return open(path, encoding="utf-8").read() if os.path.exists(path) else ""


def tunjukkan(syarat: str, lulus: bool, catatan: str = "", wajib: bool = True) -> bool:
    tanda = OK if lulus else (NO if wajib else WARN)
    print(f"  {tanda} {syarat}" + (f"  — {catatan}" if catatan else ""))
    return lulus or not wajib


def _isi_ddl(berkas: list[str]) -> bool:
    """Berkas DDL sudah diisi, bukan masih stub TODO."""
    return all("TODO" not in baca(p) for p in berkas)


def _tests_topik(topic: str) -> list[dict]:
    import yaml
    isi = baca(os.path.join(config.ROOT, "tests", "test_definitions.yml"))
    if not isi:
        return []
    data = yaml.safe_load(isi) or {}
    return [t for t in (data.get("tests") or []) if t.get("topic") == topic]


def sesi8(topic: str) -> list[bool]:
    print(f"DoD Sesi 8 — Design Checkpoint (desain saja, tidak ada yang dijalankan) · topik {topic}")
    hasil = []
    dim = sorted(glob.glob(os.path.join(config.SQL, "20_dim_*.sql")))
    fact = sorted(glob.glob(os.path.join(config.SQL, "30_fact_*.sql")))
    analitik = sorted(glob.glob(os.path.join(config.SQL, "40_analytics", "q*.sql")))
    isi_fact = baca(fact[0]) if fact else ""
    isi_dim = " ".join(baca(p) for p in dim)
    tests = _tests_topik(topic)
    kamus = baca(os.path.join(config.DOCS, "kamus_metrik.md"))
    d7 = baca(os.path.join(config.DOCS, "D7_scope_cut.md"))
    design = baca(os.path.join(config.ROOT, "pipeline", "DESIGN_load.md"))

    hasil.append(tunjukkan("DDL dimensi ada (sql/20_dim_*.sql)", len(dim) >= 3, f"{len(dim)} berkas"))
    hasil.append(tunjukkan("DDL fact ada (sql/30_fact_*.sql)", len(fact) >= 1, f"{len(fact)} berkas"))
    hasil.append(tunjukkan("DDL sudah diisi (bukan stub TODO)", _isi_ddl(dim + fact),
                           "masih ada berkas bertanda TODO"))
    hasil.append(tunjukkan("surrogate key dipakai di fact", bool(re.search(r"\w+_sk\b", isi_fact))))
    hasil.append(tunjukkan("ada dimensi Type 2 (valid_from/valid_to/is_current)",
                           all(k in isi_dim.lower() for k in ("valid_from", "valid_to", "is_current"))))
    hasil.append(tunjukkan("aditivitas ditandai (additive / semi / non-additive)",
                           bool(re.search(r"additive", isi_fact + isi_dim, re.I))))
    hasil.append(tunjukkan("pipeline/DESIGN_load.md terisi (tanpa TODO)", len(design) > 200 and "TODO" not in design,
                           f"{len(design)} karakter"))
    hasil.append(tunjukkan(f"6 test kualitas untuk topik {topic}", len(tests) >= 6, f"{len(tests)} test"))
    hasil.append(tunjukkan("setiap test punya severity + justifikasi",
                           bool(tests) and all(t.get("severity") in ("blocking", "warning") and t.get("justifikasi") for t in tests)))
    gagal = sum(1 for t in tests if t.get("expected") == "fail")
    hasil.append(tunjukkan("ada test yang diharapkan FAIL", gagal >= 1, f"{gagal} test"))
    hasil.append(tunjukkan("3 kueri analitik sudah diisi", len(analitik) >= 3 and
                           all("TODO" not in baca(p) for p in analitik), f"{len(analitik)} berkas"))
    sel = len(re.findall(r"\|\s*[0-9]+\s*\|[^|]*\|[^|]*\S", kamus))
    hasil.append(tunjukkan("kamus metrik: ≥10 dari 12 field terisi", sel >= 10, f"{sel} baris terisi"))
    hasil.append(tunjukkan("D7 scope cut: bagian AKAN dan TIDAK LAGI terisi",
                           "AKAN" in d7.upper() and "TIDAK" in d7.upper()))
    hasil.append(tunjukkan("D7 ditandatangani", "tanda tangan" in d7.lower()))
    return hasil


def sesi4(topic: str, slice_id: str) -> list[bool]:
    print(f"DoD Sesi 4 — D3 load idempoten ({topic}/{slice_id})")
    db = config.db_path(topic, slice_id)
    pakai_fallback = False
    if not os.path.exists(db):
        alternatif = os.path.join(config.WAREHOUSE, "fallback", f"{topic}_{slice_id}.duckdb")
        if os.path.exists(alternatif):
            db, pakai_fallback = alternatif, True
    hasil = [tunjukkan(f"warehouse ada ({os.path.relpath(db, config.ROOT)})", os.path.exists(db))]
    if pakai_fallback:
        hasil.append(tunjukkan("Pakai jalur penyelamat — artefak D3 tim belum ada", False,
                               "katakan terus terang ke dosen; fallback tidak bisa dijelaskan sebagai kerja tim",
                               wajib=False))
    if os.path.exists(db):
        import duckdb
        con = duckdb.connect(db, read_only=True)
        tabel = [r[0] for r in con.execute(
            "SELECT table_name FROM information_schema.tables WHERE table_schema='main'").fetchall()]
        fat = config.TOPICS[topic]["fact"]
        hasil.append(tunjukkan(f"fact `{fat}` ada", fat in tabel, ", ".join(sorted(tabel)[:6])))
        if fat in tabel:
            n = con.execute(f'SELECT count(*) FROM "{fat}"').fetchone()[0]
            hasil.append(tunjukkan("fact berisi baris", n > 0, f"{n:,} baris"))
            orbit = con.execute(f'SELECT count(*) FROM "{fat}" f WHERE f.date_sk IS NULL').fetchone()[0]
            hasil.append(tunjukkan("semua baris fact punya date_sk (dim_date ter-join)", orbit == 0,
                                   f"{orbit:,} baris tanpa tanggal"))
        con.close()
    return hasil


def sesi5(topic: str, slice_id: str) -> list[bool]:
    print(f"DoD Sesi 5 — D4 test kualitas ({topic}/{slice_id})")
    tests = _tests_topik(topic)
    isi = " ".join(str(t.get("sql", "")) for t in tests)
    hasil = [tunjukkan(f"≥6 test untuk topik {topic}", len(tests) >= 6, f"{len(tests)} test")]
    hasil.append(tunjukkan("≥1 test blocking", any(t.get("severity") == "blocking" for t in tests)))
    hasil.append(tunjukkan("≥1 test warning", any(t.get("severity") == "warning" for t in tests)))
    hasil.append(tunjukkan("≥1 test diharapkan FAIL", any(t.get("expected") == "fail" for t in tests)))
    hasil.append(tunjukkan("tidak ada test `WHERE 1=1`", "1=1" not in isi))
    hasil.append(tunjukkan("setiap test punya justifikasi", all(t.get("justifikasi") for t in tests)))
    return hasil


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["verify"])
    ap.add_argument("--sesi", required=True, choices=["4", "5", "8"])
    ap.add_argument("--topic", default="t2", choices=sorted(config.TOPICS))
    ap.add_argument("--slice", default=None)
    args = ap.parse_args()

    slice_id = args.slice or sorted(config.TOPICS[args.topic]["slices"])[0]
    hasil = {"8": lambda: sesi8(args.topic), "4": lambda: sesi4(args.topic, slice_id),
             "5": lambda: sesi5(args.topic, slice_id)}[args.sesi]()

    lulus, total = sum(1 for h in hasil if h), len(hasil)
    print(f"\n{lulus}/{total} syarat terpenuhi")
    if args.sesi == "8" and lulus < total:
        print("Desain belum bisa dieksekusi orang lain. Perbaiki yang bertanda ✗ sebelum keluar ruangan.")
    sys.exit(0 if lulus == total else 1)


if __name__ == "__main__":
    main()
