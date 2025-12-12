# TTRPG Database Manager

## Gereksinimler

- PostgreSQL 16+
- Python 3.10+

## Kurulum

1. DB'yi kur:

- pgAdmin Query Tool ile `sql/01_schema.sql`, `sql/02_seed.sql`, `sql/03_procs_triggers.sql` çalıştır.

2. Uygulama bağımlılıkları:

```bash
cd app
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```
