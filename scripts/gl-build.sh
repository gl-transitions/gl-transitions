#!/bin/bash
set -e

nodeVersion=`node -v`
cd ~/.nvm/versions/node/$nodeVersion/lib/node_modules/gl-transition-scripts/node_modules/gl
npm run rebuild
