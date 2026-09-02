# Starter

A FastAPI + Postgres + Vite/React stack that runs in Docker.

## Run

macOS, Linux, or WSL:

```bash
./preflight.sh
make up
```

Windows (PowerShell + Docker Desktop):

```powershell
powershell -ExecutionPolicy Bypass -File .\preflight.ps1
docker compose up --build -d
```

- frontend: http://127.0.0.1:3000
- API health: http://127.0.0.1:8000/api/health
- API docs: http://127.0.0.1:8000/docs

If something else is already listening on port 3000, `http://localhost:3000` may hit that process instead of this stack. Use `http://127.0.0.1:3000`, or free the port.

## Dependencies

Adding a library? Edit `requirements.txt` or `package.json`, then run `make deps`.

On Windows without Make:

```powershell
docker compose exec web npm install
docker compose exec api pip install -r requirements.txt
docker compose restart api
```

`node_modules` lives in a container volume, so a plain rebuild will not pick it up.

`make help` lists the other targets. On Windows without Make, the equivalents are the `docker compose` commands in the Makefile.
