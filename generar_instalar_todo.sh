#!/bin/sh
# Vuelve a generar INSTALAR_TODO.sql uniendo los archivos numerados 001…899 en orden.
# Los datos de ejemplo (900_…) quedan aparte.
cd "$(dirname "$0")"
{
  echo '-- ====================================================================='
  echo '-- INSTALAR_TODO.sql · Generado uniendo 001 a 899 en orden. Pegar completo en el'
  echo '-- SQL Editor de Supabase y presionar RUN. (Los datos de ejemplo van aparte.)'
  echo '-- Para actualizar una base que YA está en uso, NO use este archivo: pegue solo'
  echo '-- los archivos nuevos (vea LEEME.md, sección "Actualizar una base en uso").'
  echo '-- ====================================================================='
  for f in $(ls [0-8][0-9][0-9]_*.sql | sort); do
    printf '\n-- >>>>>>>>>>>>>>>>>>>> %s\n' "$f"
    cat "$f"
  done
} > INSTALAR_TODO.sql
echo "INSTALAR_TODO.sql generado."
