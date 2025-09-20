#!/bin/bash

# Màu sắc cho log
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

log() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${RESET} $1"
}

warn() {
  echo -e "${YELLOW}⚠️  $1${RESET}"
}

error() {
  echo -e "${RED}❌ $1${RESET}"
}

note() {
  echo -e "\n🔹 $1\n"
}
