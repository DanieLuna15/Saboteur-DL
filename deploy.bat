@echo off
echo 🚀 Compilando Saboteur Online...
call flutter build web --release
echo ⬆️ Desplegando en Firebase Hosting...
call firebase deploy --only hosting
echo ✅ ¡Listo! El juego ya está actualizado en la web.
pause
