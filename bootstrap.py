#!/usr/bin/env python3
"""Setup untuk Business Intelligence Systems (SDA2161).

Jalankan sekali sebelum Sesi 3:

    python bootstrap.py

Skrip ini hanya memakai pustaka bawaan Python, jadi ia bisa jalan sebelum
apa pun terpasang. Kalau ada yang gagal, pesan errornya ditulis dalam bahasa
yang bisa kamu salin langsung ke thread RISE.
"""

import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
MIN_PYTHON = (3, 10)

# Berkas milik dosen. `--update` menimpa berkas ini; berkas lain milik kamu
# dan tidak pernah disentuh.
DOSEN_OWNED = [
    "bootstrap.py",
    "checkpoint.py",
    "pipeline/",
    "dashboard/build.py",
    "dashboard/charts.py",
    "tests/run_tests.py",
    "sql/00_profiling.sql",
    "sql/10_dim_date.sql",
    "models/",
    "notebooks/",
]

UPDATE_URL = "https://github.com/pramudityad/bis-cakrawala-starter/archive/refs/heads/main.zip"


class SetupError(Exception):
    """Kegagalan yang sudah punya pesan layak-baca untuk mahasiswa."""


def say(msg=""):
    print(msg, flush=True)


def step(n, total, label):
    say(f"[{n}/{total}] {label}")


def check_python():
    got = sys.version_info[:2]
    if got < MIN_PYTHON:
        raise SetupError(
            f"Python kamu {got[0]}.{got[1]}, minimal {MIN_PYTHON[0]}.{MIN_PYTHON[1]}.\n"
            f"  Windows : install dari python.org, CENTANG 'Add Python to PATH'\n"
            f"  macOS   : brew install python@3.12\n"
            f"  Lalu tutup terminal, buka lagi, jalankan ulang skrip ini."
        )
    return f"Python {got[0]}.{got[1]} OK"


def check_pip():
    try:
        subprocess.run(
            [sys.executable, "-m", "pip", "--version"],
            check=True, capture_output=True, timeout=60,
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        raise SetupError(
            "pip tidak tersedia untuk Python ini.\n"
            "  Coba: python -m ensurepip --upgrade\n"
            f"  Detail: {exc}"
        ) from exc
    except subprocess.TimeoutExpired as exc:
        raise SetupError("pip tidak merespons dalam 60 detik — cek koneksi.") from exc
    return "pip OK"


def install_requirements():
    req = REPO_ROOT / "requirements.txt"
    if not req.exists():
        raise SetupError(f"requirements.txt tidak ditemukan di {REPO_ROOT}")
    proc = subprocess.run(
        [sys.executable, "-m", "pip", "install", "-r", str(req)],
        capture_output=True, text=True, timeout=600,
    )
    if proc.returncode != 0:
        tail = (proc.stderr or proc.stdout).strip().splitlines()[-12:]
        raise SetupError(
            "pip install gagal. Salin blok di bawah ke thread RISE:\n"
            + "\n".join("    " + line for line in tail)
        )
    return "Dependensi terpasang"


def check_imports():
    missing = []
    for mod in ("duckdb", "yaml"):
        try:
            __import__(mod)
        except ImportError:
            missing.append(mod)
    if missing:
        raise SetupError(
            f"Paket belum terbaca setelah install: {', '.join(missing)}.\n"
            "  Biasanya karena ada lebih dari satu Python di komputermu.\n"
            f"  Python yang dipakai skrip ini: {sys.executable}\n"
            "  Jalankan ulang dengan path itu persis."
        )
    import duckdb  # noqa: E402  (sudah dipastikan ada di atas)
    return f"duckdb {duckdb.__version__} terbaca"


def smoke_test():
    """Buat database sementara, tulis, baca, hapus. Bukti DuckDB benar jalan."""
    import duckdb  # noqa: E402

    tmp = REPO_ROOT / "warehouse" / "_smoke.duckdb"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    if tmp.exists():
        tmp.unlink()
    try:
        con = duckdb.connect(str(tmp))
        con.execute("CREATE TABLE smoke AS SELECT 1 AS satu, 'bi' AS kelas")
        rows = con.execute("SELECT satu, kelas FROM smoke").fetchall()
        con.close()
        if rows != [(1, "bi")]:
            raise SetupError(f"Smoke test mengembalikan hasil tak terduga: {rows}")
    finally:
        if tmp.exists():
            tmp.unlink()
    return "Smoke test lulus (tulis + baca DuckDB)"


def ok_line():
    """Baris yang dipaste ke RISE. Menunjukkan setup jalan, tanpa data pribadi."""
    import duckdb  # noqa: E402

    return (
        f"OK | python {sys.version_info.major}.{sys.version_info.minor}"
        f" | duckdb {duckdb.__version__}"
        f" | {platform.system()}"
        f" | repo {REPO_ROOT.name}"
    )


def update_tools():
    """Ambil versi terbaru berkas milik dosen. Kerja kamu tidak disentuh."""
    say("Mengunduh versi terbaru perkakas dosen...")
    tmp_zip = REPO_ROOT / "_update.zip"
    tmp_dir = REPO_ROOT / "_update_tmp"
    try:
        urllib.request.urlretrieve(UPDATE_URL, tmp_zip)
        with zipfile.ZipFile(tmp_zip) as zf:
            zf.extractall(tmp_dir)
        roots = [p for p in tmp_dir.iterdir() if p.is_dir()]
        if not roots:
            raise SetupError("Arsip update kosong.")
        src_root = roots[0]

        changed = []
        for rel in DOSEN_OWNED:
            src = src_root / rel
            dst = REPO_ROOT / rel
            if not src.exists():
                continue
            if src.is_dir():
                if dst.exists():
                    shutil.rmtree(dst)
                shutil.copytree(src, dst)
            else:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
            changed.append(rel)
        say("Diperbarui: " + ", ".join(changed))
        say("Berkas kerjamu (sql/, docs/, dashboard/config.yml, "
            "tests/test_definitions.yml) tidak disentuh.")
    finally:
        if tmp_zip.exists():
            tmp_zip.unlink()
        if tmp_dir.exists():
            shutil.rmtree(tmp_dir)


def main():
    if "--update" in sys.argv:
        try:
            update_tools()
        except SetupError as exc:
            say(f"\nGAGAL: {exc}")
            return 1
        except Exception as exc:  # noqa: BLE001 — pesan mentah lebih berguna di sini
            say(f"\nGAGAL mengunduh update: {exc}")
            return 1
        return 0

    say("Setup Business Intelligence Systems — SDA2161")
    say(f"Repo: {REPO_ROOT}")
    say()

    steps = [
        ("Cek versi Python", check_python),
        ("Cek pip", check_pip),
        ("Install dependensi", install_requirements),
        ("Cek paket terbaca", check_imports),
        ("Smoke test DuckDB", smoke_test),
    ]
    total = len(steps)
    for i, (label, fn) in enumerate(steps, start=1):
        step(i, total, label)
        try:
            say(f"      {fn()}")
        except SetupError as exc:
            say()
            say("=" * 60)
            say("SETUP GAGAL")
            say("=" * 60)
            say(str(exc))
            say()
            say("Balas di thread RISE dengan seluruh teks di atas.")
            say("Dibereskan di 5 menit pertama lab Sesi 3 — jangan panik.")
            return 1

    say()
    say("=" * 60)
    say("SETUP SELESAI")
    say("=" * 60)
    say()
    say("Salin baris ini ke thread RISE:")
    say()
    say("    " + ok_line())
    say()
    return 0


if __name__ == "__main__":
    sys.exit(main())
