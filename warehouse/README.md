# warehouse/

Hasil kerja, bukan sumber. Berkas `.duckdb` **tidak** di-commit (lihat `.gitignore`).

```
python -m pipeline.load --topic t2 --slice k8            # → warehouse/t2_k8.duckdb
python -m pipeline.load --topic t2 --slice k8 --twice    # bukti idempoten
python -m pipeline.load --topic t2 --slice k8 --fallback # → warehouse/fallback/t2.duckdb (jalur penyelamat)
```
