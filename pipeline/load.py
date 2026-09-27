"""D3 — load idempoten: satu dimensi + satu fact, dijalankan dua kali tanpa menggandakan baris.

Dua mode:

    full        CREATE OR REPLACE TABLE  (idempoten secara konstruksi — acuan repo ini)
    insert_only INSERT polos pada run kedua — MENGGANDAKAN baris. Hanya untuk demonstrasi Sesi 4.

Strategi lain (upsert lewat natural key, DELETE partisi + INSERT) **ditulis tim sendiri** di
`pipeline/DESIGN_load.md` dan di SQL mereka — repo ini tidak menyediakan flag untuk itu, karena
memilihnya adalah bagian dari penilaian, bukan pengaturan.

Pakai:
    python -m pipeline.load --topic t2 --slice k8 --twice
    python -m pipeline.load --topic t2 --slice k8 --strategy insert_only --twice   # demo jebol
    python -m pipeline.load --topic t1 --slice k4 --fallback                       # tulis warehouse/fallback/
"""

from __future__ import annotations

import argparse
import os
import re
import time

import duckdb

from pipeline import config


def render(sql: str, ctx: dict) -> str:
    """Isi {D} (folder seed) dan {SLICE_<nama>} (predikat slice, TRUE kalau tidak dipakai)."""
    where = ctx["cfg"]["slices"][ctx["slice"]].get("where", {})
    sql = sql.replace("{D}", ctx["dir"])
    for key in re.findall(r"\{SLICE_([a-z_]+)\}", sql):
        sql = sql.replace(f"{{SLICE_{key}}}", where.get(key, "TRUE"))
    return sql


def statements(sql: str) -> list[str]:
    return [s.strip() for s in sql.split(";") if s.strip()]


def counts(con: duckdb.DuckDBPyConnection) -> dict[str, int]:
    tabel = [r[0] for r in con.execute(
        "SELECT table_name FROM information_schema.tables WHERE table_schema='main' ORDER BY 1").fetchall()]
    return {t: con.execute(f'SELECT count(*) FROM "{t}"').fetchone()[0] for t in tabel}


def run_once(con: duckdb.DuckDBPyConnection, stmts: list[str], strategy: str, sudah_ada: bool) -> None:
    """strategi `full`   = CREATE OR REPLACE (idempoten secara konstruksi)
       strategi `insert_only` = CREATE pada run-1, INSERT polos pada run-2 (contoh yang sengaja jebol)."""
    for stmt in stmts:
        if strategy == "insert_only" and sudah_ada and re.match(r"CREATE OR REPLACE TABLE \w+ AS", stmt, re.I):
            stmt = re.sub(r"^CREATE OR REPLACE TABLE", "INSERT INTO", stmt, flags=re.I)
        con.execute(stmt)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--topic", required=True, choices=sorted(config.TOPICS))
    ap.add_argument("--slice", required=True)
    ap.add_argument("--strategy", default="full", choices=["full", "insert_only"],
                    help="full = idempoten; insert_only = contoh yang sengaja menggandakan baris")
    ap.add_argument("--twice", action="store_true", help="jalankan dua kali lalu bandingkan row count")
    ap.add_argument("--sql", default=None, help="berkas SQL tim (default: sql/load.sql)")
    ap.add_argument("--fallback", action="store_true", help="tulis ke warehouse/fallback/ (jalur penyelamat)")
    args = ap.parse_args()

    ctx = config.resolve(args.topic, args.slice)
    path = args.sql or os.path.join(config.SQL, "load.sql")
    if not os.path.exists(path):
        raise SystemExit(f"SQL tidak ditemukan: {path}")
    if "TODO" in open(path, encoding="utf-8").read():
        raise SystemExit(
            f"sql/load.sql masih kosong (bertanda TODO).\n"
            f"Tulis dulu DDL dimensi + fact timmu di sql/20_*.sql dan sql/30_*.sql, lalu susun\n"
            f"urutan eksekusinya di sql/load.sql. Contoh bentuknya ada di sql/00_profiling.sql\n"
            f"dan sql/10_dim_date.sql (yang diberikan), serta sql/20_dim_entitas_utama.sql\n"
            f"(kerangka berkomentar).")
    sql = render(open(path, encoding="utf-8").read(), ctx)
    stmts = statements(sql)

    if args.fallback:
        dest = os.path.join(config.WAREHOUSE, "fallback")
        os.makedirs(dest, exist_ok=True)
        db = os.path.join(dest, f"{args.topic}_{args.slice}.duckdb")
    else:
        db = config.db_path(args.topic, args.slice)

    con = duckdb.connect(db)
    print(f"[load] {ctx['cfg']['label']} · slice {args.slice} ({ctx['label']})")
    print(f"[load] sql={os.path.relpath(path, config.ROOT)} · strategi={args.strategy} · db={os.path.relpath(db, config.ROOT)}")

    t0 = time.time()
    run_once(con, stmts, args.strategy, sudah_ada=False)
    c1 = counts(con)
    print(f"[load] run-1 {time.time() - t0:.2f}s → " + " · ".join(f"{k}={v:,}" for k, v in c1.items()))

    if args.twice:
        t1 = time.time()
        run_once(con, stmts, args.strategy, sudah_ada=True)
        c2 = counts(con)
        beda = {k: (c1[k], c2.get(k)) for k in c1 if c1[k] != c2.get(k)}
        print(f"[load] run-2 {time.time() - t1:.2f}s → " + " · ".join(f"{k}={v:,}" for k, v in c2.items()))
        if beda:
            print("[load] ✗ TIDAK IDEMPOTEN — " + " · ".join(f"{k}: {a:,} → {b:,}" for k, (a, b) in beda.items()))
            print("[load]   penyebab paling umum: INSERT tanpa klausa kunci, atau grain fact yang tidak unik")
        else:
            print("[load] ✓ IDEMPOTEN — row count run-1 == run-2")
    con.close()


if __name__ == "__main__":
    main()
