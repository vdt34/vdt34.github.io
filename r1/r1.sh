#!/bin/sh
# Phicomm R1 Installer Loader (iSH / Linux / Termux)
# https://vdt34.github.io/r1/r1.sh

if command -v apk >/dev/null 2>&1; then
    [ -f /etc/apk/repositories ] && sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories 2>/dev/null
    if ! command -v curl >/dev/null 2>&1 || ! command -v adb >/dev/null 2>&1; then
        echo ">> Dang chuan bi moi truong cai dat (curl, android-tools)..."
        apk update >/dev/null 2>&1 || true
        apk add --no-cache curl android-tools ca-certificates >/dev/null 2>&1 || true
    fi
elif command -v pkg >/dev/null 2>&1; then
    if ! command -v curl >/dev/null 2>&1 || ! command -v adb >/dev/null 2>&1; then
        echo ">> Dang chuan bi moi truong cai dat..."
        pkg install -y curl android-tools >/dev/null 2>&1 || true
    fi
elif command -v apt-get >/dev/null 2>&1; then
    if ! command -v curl >/dev/null 2>&1 || ! command -v adb >/dev/null 2>&1; then
        echo ">> Dang chuan bi moi truong cai dat..."
        apt-get update -y >/dev/null 2>&1 && apt-get install -y curl adb >/dev/null 2>&1 || true
    fi
fi

TS=$(date +%s 2>/dev/null || echo "1")
exec sh -c "$(curl -fsSL https://vdt34.github.io/r1/install.sh?t=$TS)"
