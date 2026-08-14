# CCD-7877 Hardcoded Credentials

## Objective

Remove tracked credential material and provide safe local runtime configuration without committing secrets.

## Acceptance criteria

- No `.env`, plaintext secret file, or hardcoded credential remains tracked.
- Compose and helper scripts require runtime-supplied values.
- Local setup generates persistent ignored values and certificates.
- Shared environments use approved secret injection.
- No live credential rotation is performed by this change.

## Validation

- Shell syntax checks passed.
- Default Compose interpolation passed with a disposable generated environment.
- Bootstrap scenarios passed for existing, missing, and non-local environments.
- Docker runtime validation remains outstanding.

## Scope and findings

Remediation status: tracked `.env`, plaintext secret files, and credential defaults have been removed or externalised. `bin/setup-local-secrets.sh` generates ignored local-only values; no live credential rotation was performed.

Bulk-user setup now requires `IDAM_ADMIN_USER`, `IDAM_ADMIN_PASSWORD`, and `IDAM_BULK_USER_CLIENT_SECRET`; its local database helpers use the generated `IDAM_DB_PASSWORD`.

- Tracked `.env` contains database passwords, IDAM service keys, OAuth2 client secrets, App Insights configuration, and `CCD_NEXT_HEARING_DATE_PASSWORD`.
- Tracked plaintext files: `secrets/rpx/appinsights-connection-string-mc` and `secrets/rpx/postgresql-admin-pw`.
- Compose and helper scripts reference `.env`, the tracked secret directory, and related service configuration.
- Existing replacement names include `DB_PASSWORD`, `AM_DB_PASSWORD`, `IDAM_KEY_*`, `OAUTH2_CLIENT_CCD_GATEWAY`, `OAUTH2_CLIENT_CCD_ADMIN`, `APPINSIGHTS_INSTRUMENTATIONKEY`, and `CCD_NEXT_HEARING_DATE_PASSWORD`.
- Credential-related history exists, but does not prove current values were rotated.

## Validity and deployment

- Current validity: **not confirmed**; no live authentication or secret-store access was available.
- Deployment/runtime: repository evidence confirms local Compose consumption; live environments, CI variables, cloud stores, and running containers were not accessible.
- Rotation: **not confirmed** for tracked `.env` values or plaintext files.

## Recommendations

Treat all tracked values as compromised. Revoke/rotate, remove `.env` and plaintext files from source and history, and inject values at runtime through a managed secret store or untracked local mechanism. Reuse the existing variable names. Verify live secret-store references, deployed containers, CI/CD variables, and rotation records before closure.

## Local operation

Run `./bin/setup-local-secrets.sh` once for a new local checkout, then `source ./bin/set-environment-variables.sh`. It creates a persistent ignored `.env` and `.local-secrets/` HTTPS files; rerunning it preserves an existing environment file. Set `CCD_ENV=aat` (or another non-local value) with `CCD_ENV_FILE` for externally managed environments; no local values are generated in that mode. An approved fixed-defaults-file fallback is not currently implemented.

### Local and shared environment behavior

| Setting | Behavior |
|---|---|
| Existing `.env` | Preserved; the bootstrap refuses to overwrite it. |
| Missing `.env`, `CCD_ENV=local` | A persistent ignored `.env` and local HTTPS files are generated. |
| `CCD_ENV=aat` or another non-local value | No values are generated; an approved `CCD_ENV_FILE` must be supplied. |
| `CCD_ENV_FILE` | Path to an externally managed environment file; it is not fetched automatically. |
| Standalone application HTTPS | Set `HTTPS_CERT_PATH` and `HTTPS_KEY_PATH` to locally managed files. |

Typical local setup:

```bash
./bin/setup-local-secrets.sh
source ./bin/set-environment-variables.sh
./ccd compose up -d
```

Shared environments must use approved secret-store or CI/CD values. Local generated values must not be reused in AAT, staging, or production.

## Validation instructions

### Configuration validation

From `ccd-docker`:

```bash
./bin/setup-local-secrets.sh
source ./bin/set-environment-variables.sh
docker compose --env-file .env -f compose/backend.yml -f compose/frontend.yml -f compose/idam-sim.yml config --quiet
```

This checks variable interpolation without starting containers.

### Runtime validation

Start the default stack first, then build and enable the changed application images. `./ccd default` resets project overrides, so the order matters:

```bash
./ccd default
./ccd set ccd-api-gateway CCD_7877_Hardcoded_Credentials file://../ccd-api-gateway
./ccd set ccd-admin-web CCD_7877_Hardcoded_Credentials file://../ccd-admin-web
./ccd compose up -d
./ccd compose ps
```

Check service health and logs:

```bash
curl --fail --silent --show-error http://localhost:3453/health
curl --fail --silent --show-error http://localhost:4451/health
curl --fail --silent --show-error http://localhost:4452/health
curl --fail --silent --show-error http://localhost:4453/health
./ccd compose logs --tail=100
```

`ccd-case-print-service` is not part of the default `ccd-docker` project/Compose stack and requires separate standalone validation. Do not run `down -v` during cleanup because it removes local database volumes.
