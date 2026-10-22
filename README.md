# perri-watch

The outside watcher for Perri's production service. Every 5 minutes a GitHub Action checks `/health`; after two misses
in a row it sends one text, and one more when the service answers again. It runs here, outside the service, so it can
still speak when the service cannot. `state.json` is its memory; `heartbeat.txt` keeps the schedule alive.
