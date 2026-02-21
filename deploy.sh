#!/bin/bash
# Usage: ./deploy.sh "description du changement"
set -e

MSG="${1:-update}"

git add -A
git commit -m "$MSG"
git push origin main

echo ""
echo "Deploiement lance :"
echo "  - Render  : https://dashboard.render.com (build ~5-10 min)"
echo "  - Pages   : https://github.com/The-Cyril5555/shadow_hunter_app/actions"
echo "  - Jeu     : https://the-cyril5555.github.io/shadow_hunter_app/"
