#!/bin/bash

# Farger for terminal output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "${GREEN}Genererer launcher icons og native splash...${NC}"

# Kjør flutter pub get for å sikre at alle avhengigheter er oppdaterte
echo "${GREEN}Kjører flutter pub get...${NC}"
flutter pub get

# Generer native splash screen
echo "${GREEN}Genererer native splash screen...${NC}"
flutter pub run flutter_native_splash:create

# Generer app icons
echo "${GREEN}Genererer app icons...${NC}"
dart run flutter_launcher_icons

echo "${GREEN}Ferdig! Alle assets er generert.${NC}" 