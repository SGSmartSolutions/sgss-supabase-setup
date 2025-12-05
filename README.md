# SGSS Supabase Setup

This repository is a **template** to bootstrap multiple self-hosted Supabase projects
on a single Ubuntu server, with **hard separation** (one Supabase stack per app).

- Base setup (Docker, UFW, jq)
- Traefik reverse proxy + Let's Encrypt (HTTPS)
- Separate Supabase stack per project:
  - own Postgres database
  - own Studio
  - own API URL
  - own keys

> ⚠️ This repo is designed to be **public**.  
> Real configuration and secrets are only created on the server and are ignored via `.gitignore`.

---

## Folder structure

```text
configs/
  supabase-projects.example.json   # example config (in git)
  supabase-projects.json           # real config (created on server, ignored by git)

scripts/
  00_base_setup.sh                 # system updates, Docker, firewall
  01_traefik_setup.sh              # Traefik + proxy network
  02_supabase_per_project.sh       # Supabase stacks per project
  run_all.sh                       # run everything in order
