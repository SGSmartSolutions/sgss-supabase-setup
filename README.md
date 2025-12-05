# SGSS Supabase Multi-Setup

This repository is a **template** to bootstrap multiple self-hosted Supabase projects
on a single Ubuntu server, with **hard separation** (one Supabase stack per app).

You get:

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
  supabase-projects.example.json   # example config (committed to git)
  supabase-projects.json           # real config (created on server, ignored by git)

scripts/
  00_base_setup.sh                 # system updates, Docker, firewall
  01_traefik_setup.sh              # Traefik + proxy network
  02_supabase_per_project.sh       # Supabase stacks per project
  run_all.sh                       # run everything in order

.gitignore                         # ignores real config and secrets
README.md


⸻

How to use (on a fresh server)

1. Clone the repo

git clone https://github.com/SGSmartSolutions/sgss-supabase-setup.git
cd sgss-supabase-multi-setup

Replace YOUR-ORG with your GitHub username or organization.

⸻

2. Create your real config from the example

cp configs/supabase-projects.example.json configs/supabase-projects.json
nano configs/supabase-projects.json

Edit configs/supabase-projects.json to match your environment:

Under "base":
	•	ssh_port – your SSH port (22 by default)
	•	letsencrypt_email – email for Let’s Encrypt notifications
	•	traefik_dashboard_domain – domain for the Traefik dashboard
(e.g. traefik.example.com)

Under "projects": one entry per app / Supabase project, for example:

{
  "id": "inbox",
  "description": "SGSS Inbox / Ticket App",
  "supabase_dir": "/opt/supabase-inbox",
  "studio_domain": "studio.inbox.example.com",
  "api_domain": "api.inbox.example.com",
  "admin_email": "inbox-admin@example.com"
}

Field meanings:
	•	id
Short identifier for the project (used internally in container names, etc.).
	•	description
Human-readable description (for documentation only).
	•	supabase_dir
Directory where this project’s Supabase stack will live on the server.
	•	studio_domain
Domain under which Supabase Studio for this project will be reachable.
	•	api_domain
Domain under which the Supabase API for this project will be reachable.
	•	admin_email
Admin/contact email for this project (you can reuse the same email).

You can start with a single project and add more later.

⸻

3. Make scripts executable

chmod +x scripts/*.sh


⸻

4. Run the full setup

./scripts/run_all.sh

This will:
	1.	Install Docker and docker-compose (if not present).
	2.	Configure UFW firewall:
	•	deny all incoming traffic by default
	•	allow:
	•	SSH on ssh_port from your config
	•	HTTP (80)
	•	HTTPS (443)
	3.	Start Traefik on ports 80/443 with Let’s Encrypt.
	4.	For each project in configs/supabase-projects.json:
	•	clone/copy the Supabase Docker setup into its own directory
	•	generate a .env file with random secrets
	•	start a dedicated Supabase stack using Docker Compose, with a unique COMPOSE_PROJECT_NAME.

⸻

Running individual steps

If you prefer to run the steps manually, you can execute each script separately:

Base setup only

./scripts/00_base_setup.sh

Traefik setup only

./scripts/01_traefik_setup.sh

Supabase stacks for all projects

./scripts/02_supabase_per_project.sh

Supabase stack for a single project

You can pass a specific project ID (as in supabase-projects.json) to only set up or restart that one project:

./scripts/02_supabase_per_project.sh inbox

This is useful if you add a new project later or want to re-run the setup for one project without touching the others.

⸻

DNS & Traefik routing for Supabase

For each domain defined in configs/supabase-projects.json:

1. DNS records

At your DNS provider, create A records pointing to this server’s public IP:
	•	traefik_dashboard_domain from "base"
(e.g. traefik.example.com)
	•	For each project:
	•	studio_domain (e.g. studio.inbox.example.com)
	•	api_domain (e.g. api.inbox.example.com)

Example:

traefik.example.com           A   203.0.113.42
studio.inbox.example.com      A   203.0.113.42
api.inbox.example.com         A   203.0.113.42
studio.portal.example.com     A   203.0.113.42
api.portal.example.com        A   203.0.113.42
...

2. Traefik labels & proxy network in Supabase stacks

The scripts only start the Supabase Docker stacks. To expose Supabase Studio and the API through Traefik, you must:
	•	Attach the relevant Supabase services to the proxy network.
	•	Add Traefik labels (traefik.http.routers.* and traefik.http.services.*) to these services.

The exact service names and ports depend on the Supabase Docker setup version.
Typically, there will be:
	•	a Studio service (React app, port like 3000)
	•	an API gateway service (Kong, port like 8000/8001)

Example (pseudo, adapt to the real docker-compose):

services:
  studio:
    # ... existing config from Supabase ...
    networks:
      - default
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.inbox-studio.rule=Host(`studio.inbox.example.com`)"
      - "traefik.http.routers.inbox-studio.entrypoints=websecure"
      - "traefik.http.routers.inbox-studio.tls.certresolver=letsencrypt"
      - "traefik.http.services.inbox-studio.loadbalancer.server.port=3000"

  kong:
    # ... existing config from Supabase ...
    networks:
      - default
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.inbox-api.rule=Host(`api.inbox.example.com`)"
      - "traefik.http.routers.inbox-api.entrypoints=websecure"
      - "traefik.http.routers.inbox-api.tls.certresolver=letsencrypt"
      - "traefik.http.services.inbox-api.loadbalancer.server.port=8000"

networks:
  proxy:
    external: true

Repeat a similar pattern for each project, using different router/service names and domains
(e.g. portal-studio, portal-api, etc.).

⸻

Security notes
	•	configs/supabase-projects.json is ignored by git (see .gitignore).
	•	It is created from the example file and should only exist on the server (with your real domains/mail/paths).
	•	All .env files generated for Supabase projects are ignored by git.
	•	These contain secrets: JWT secret, anon key, service role key, Postgres password.
	•	acme.json (Let’s Encrypt certificate storage) is also ignored and must never be committed.

Additional hardening is recommended:
	•	Protect Supabase Studio behind:
	•	Traefik middlewares (basic auth, IP whitelist), or
	•	a VPN
	•	Limit SSH access (keys only, change SSH port, fail2ban, etc. depending on your security policy).
	•	Regularly update the server and Docker images.

Never expose your SERVICE_ROLE_KEY to any frontend.
Use the ANON_KEY in public apps and keep service keys strictly server-side.

⸻

Updating / adding new projects later

To add a new Supabase project (e.g. academy):
	1.	Edit configs/supabase-projects.json and add a new object under "projects":

{
  "id": "academy",
  "description": "Academy app",
  "supabase_dir": "/opt/supabase-academy",
  "studio_domain": "studio.academy.example.com",
  "api_domain": "api.academy.example.com",
  "admin_email": "academy-admin@example.com"
}

	2.	Run:

./scripts/02_supabase_per_project.sh

This will:
	•	leave existing project stacks intact
	•	create and start the new Supabase stack for academy

Alternatively, to run for just one project ID:

./scripts/02_supabase_per_project.sh academy

	3.	Add DNS records for studio.academy.example.com and api.academy.example.com
and configure Traefik labels for this new project in its docker-compose.yml.

⸻

Notes / next steps

This repo is a starting point. You can extend it with:
	•	SQL migration scripts per project (sql/ directory), to:
	•	create tables
	•	enable Row Level Security (RLS)
	•	define policies for your apps
	•	Additional scripts to automatically apply migrations after the Supabase stack is up.
	•	Monitoring / alerting (Prometheus, Grafana, health checks).
	•	Automated backups (e.g. cron jobs for pg_dump to external storage).

The goal is that you (and partners) can:
	1.	Download this repo.
	2.	Edit one JSON config file on the server.
	3.	Run a few scripts.
	4.	Get a fully working, multi-project, self-hosted Supabase environment with clean separation between apps.

