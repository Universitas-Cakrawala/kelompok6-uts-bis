"""Konfigurasi topik & slice. Satu sumber kebenaran untuk profile/load/tests/checkpoint.

Dipisah dari kode supaya tim bisa melihat data apa yang mereka pegang tanpa membaca SQL:
tiap topik punya daftar slice, berkas seed, dan SQL acuan (jalur penyelamat).
"""

from __future__ import annotations

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "raw")
SQL = os.path.join(ROOT, "sql")
WAREHOUSE = os.path.join(ROOT, "warehouse")
DOCS = os.path.join(ROOT, "docs")

# Slice = potongan data per tim. Skema sama, isi berbeda → jawaban tidak bisa disalin.
TOPICS = {
    "t1": {
        "label": "T1 Kampus — Presensi & Kelulusan",
        "dir": "t1_kampus",
        "slices": {
            "k4": {"label": "Angkatan 2024", "where": {"mahasiswa": "angkatan = '2024'"}},
            "k5": {"label": "Angkatan 2023", "where": {"mahasiswa": "angkatan = '2023'"}},
            "k7": {"label": "Angkatan 2022", "where": {"mahasiswa": "angkatan = '2022'"}},
        },
        "files": ["mahasiswa.csv", "matakuliah.csv", "presensi.csv", "nilai.csv"],
        "fact": "fact_presensi",
        "grain": "Satu baris = satu mahasiswa pada satu pertemuan satu mata kuliah.",
    },
    "t2": {
        "label": "T2 POS UMKM — Multi-Outlet",
        "dir": "t2_umkm",
        "slices": {
            "k8": {"label": "Outlet A+B+C, 12 bulan",
                   "where": {"outlet_dim": "outlet_id IN ('OUT-A','OUT-B','OUT-C')",
                             "outlets": "t.outlet_id IN ('OUT-A','OUT-B','OUT-C')",
                             "hari": "TRUE"}},
            "k9": {"label": "Outlet A saja, 6 bulan (scope -20%)",
                   "where": {"outlet_dim": "outlet_id = 'OUT-A'",
                             "outlets": "t.outlet_id = 'OUT-A'",
                             "hari": "CAST(t.waktu AS DATE) >= DATE '2025-01-01' AND CAST(t.waktu AS DATE) < DATE '2025-07-01'"}},
        },
        "files": ["outlets.csv", "products.csv", "customers.csv", "transactions.csv", "transaction_items.csv"],
        "fact": "fact_sales_item",
        "grain": "Satu baris = satu item produk pada satu transaksi.",
    },
    "t3": {
        "label": "T3 Cuaca Ekstrem per Desa (BMKG)",
        "dir": "t3_publik",
        "slices": {
            "k1": {"label": "Kota Bogor (Jawa Barat)"},
            "k2": {"label": "Kota Semarang (Jawa Tengah)"},
            "k3": {"label": "Kota Makassar (Sulawesi Selatan)"},
            "k6": {"label": "Kota Denpasar (Bali)"},
        },
        "files": ["provinsi.csv", "kabkot.csv", "kecamatan.csv", "desa.csv", "prakiraan_cuaca.csv"],
        "fact": "fact_prakiraan_cuaca",
        "grain": "Satu baris = satu desa pada satu slot prakiraan.",
    },
}


def topic_dir(topic: str) -> str:
    """Folder seed untuk topik (khusus T3, folder slice ada di dalamnya)."""
    return os.path.join(DATA, TOPICS[topic]["dir"])


def resolve(topic: str, slice_id: str) -> dict:
    cfg = TOPICS[topic]
    if topic == "t3":
        directory = os.path.join(topic_dir(topic), slice_id)
        label = cfg["slices"][slice_id]["label"]
    else:
        directory = topic_dir(topic)
        label = cfg["slices"][slice_id]["label"]
    if not os.path.isdir(directory):
        raise SystemExit(f"Folder seed tidak ada: {directory}. Salin `seed/` vault ke data/raw/ dulu.")
    return {"topic": topic, "slice": slice_id, "dir": directory, "label": label, "cfg": cfg}


def db_path(topic: str, slice_id: str) -> str:
    os.makedirs(WAREHOUSE, exist_ok=True)
    return os.path.join(WAREHOUSE, f"{topic}_{slice_id}.duckdb")
