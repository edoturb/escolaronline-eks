#!/bin/bash
set -e
cd "$(dirname "$0")"
chmod +x scripts/*.sh
case "$1" in
  up) ./scripts/01-infra.sh && ./scripts/heal.sh && ./scripts/02-app.sh ;;
  deploy) ./scripts/02-app.sh ;;
  heal) ./scripts/heal.sh ;;
  status) ./scripts/status.sh ;;
  down) ./scripts/03-teardown.sh "$2" ;;
  *) echo "Uso: ./run.sh {up|deploy|heal|status|down [--full]}"; exit 1 ;;
esac
