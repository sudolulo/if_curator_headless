# if-curator-headless

fork of [if-curator](https://github.com/ds-sebastian/if_curator) with automatic Frigate face training upload and Docker support.

## What This Adds

- **Headless mode** — runs without interactive prompts, suitable for Docker and cron
- **Auto-discover people** — processes all named people from Immich automatically instead of picking one at a time
- **Frigate upload** — sends curated face crops directly to Frigate's face training API after processing
- **People filtering** — skip specific people, whitelist only certain people, or set a minimum photo count
- **Docker** — Dockerfile and compose config with NVIDIA GPU support, ready for TrueNAS

All of if-curator's original functionality (smart diversity, quality filtering, face alignment, blur rejection, etc.) is unchanged.

## New Environment Variables

| Variable | Default | What it does |
| :--- | :--- | :--- |
| `AUTO_MODE` | `false` | Run without prompts |
| `FRIGATE_URL` | *(empty)* | Frigate server URL — auto-uploads faces when set |
| `TRAINING_MODE` | `face` | `face` or `object` |
| `STRATEGY` | `auto` | `auto`, `standard`, or `broad` |
| `SKIP_PEOPLE` | *(empty)* | People to skip |
| `ONLY_PEOPLE` | *(empty)* | People to process (whitelist) |
| `MIN_FACE_COUNT` | `3` | Minimum photos required to process a person |
| `OBJECT_CLASS` | `dog` | Object type (only for object mode) |

All original if-curator variables (`IMMICH_URL`, `API_KEY`, `FORCE_CPU`, etc.) still work.

## Docker

ghcr.io/sudolulo/if-curator-headless:latest
 
