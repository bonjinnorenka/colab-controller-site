# colab-controller public site

Public homepage and privacy policy for the `colab-controller` OAuth
application. This repository contains only static HTML; no application code,
credentials, or private operational data.

## Sugakura Static App

The site is deployed as an independent Sugakura app:

| Item | Value |
|---|---|
| App ID | `colab-controller-site` |
| Runtime | `static` |
| Public files | `public/index.html`, `public/privacy.html` |
| DB / secrets / cron | none |
| Custom domain | none (Sugakura-issued managed domain) |

It is deliberately **not** combined with the `colab-controller` WASM app.
The controller keeps its own App ID, DB, secrets, cron schedule, and worker
integration; updating this site never restarts or reconfigures it.

The published URL is assigned by the provisioner and printed by
`sgctl apply`. The verified production URL is:

- Homepage: <https://colab-controller-site.sugakura.ryokuryu.com/>
- Privacy policy: <https://colab-controller-site.sugakura.ryokuryu.com/privacy.html>

Always treat the `sgctl` output as authoritative if the app is recreated.

## Layout

```text
public/                     # the only directory exposed by the static runtime
├── index.html
└── privacy.html
deploy/
├── sgctl.colab-controller-site.json   # app spec (root is rendered by apply.sh)
├── apply.sh                           # install public/ + `sgctl apply` (on BOX1)
├── deploy.sh                          # rsync from a workstation + remote apply
└── verify.sh                          # external HTTP/HTTPS verification
```

Repository metadata, deployment scripts, and logs live outside `public/`, so
the static runtime cannot serve them. The static runtime already rejects
dotfiles, traversal, and non-GET/HEAD methods; the site does not reimplement
those checks.

## Deploy

Prerequisites:

- SSH access to the Sugakura host.
- `~/sugakura-prod/remote/sgctl` installed there (existing deploy machinery).
- The provisioner reachable from the host; no local secrets are added to this
  repository.

From this repository:

```bash
SG_HOST=umupumxy@183.90.183.154 bash deploy/deploy.sh
```

This uploads `public/` and `deploy/` to
`~/sugakura-apps/colab-controller-site/`, then runs:

```bash
SUGAKURA_HOME=~/sugakura-prod ~/sugakura-prod/remote/sgctl apply <rendered-spec>
```

The first apply creates the managed domain through the existing provisioner
and waits for AutoSSL. Later applies reuse the same resources and only
replace static files / refresh the app definition. No gateway restart is
needed, and only the `colab-controller-site` app is touched.

On the host, the same apply step can be run directly after updating files:

```bash
SUGAKURA_HOME=~/sugakura-prod bash ~/sugakura-apps/colab-controller-site/deploy/apply.sh
```

## Verify

```bash
bash deploy/verify.sh https://<published-domain>
```

Checks: `GET /`, `GET /index.html`, `GET /privacy.html`, `HEAD /`, HTML
Content-Type, 404 for missing/traversal/dotfile paths, rejected `POST /`
without content mutation, page links, and TLS validation.

## Rollback / removal

The app is independent, so removal does not affect the controller:

```bash
~/sugakura-prod/remote/sgctl delete colab-controller-site
```

To stop publishing without deleting the app, remove files from
`~/sugakura-apps/colab-controller-site/public/`.

## GitHub Pages

GitHub Pages has been disabled. The GitHub repository is kept for source
management; the old `bonjinnorenka.github.io/colab-controller-site/` URL is
not redirected.
