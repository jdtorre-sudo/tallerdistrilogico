#!/bin/sh
# Recrea la base de pruebas local desde cero (PostgreSQL en /tmp/pgtest:55432).
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR/../base_de_datos"
P="psql -h /tmp/pgtest -p 55432 -U postgres -v ON_ERROR_STOP=1 -q"
$P -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='taller' and pid<>pg_backend_pid()" >/dev/null
$P -c "drop database if exists taller" -c "create database taller"
for f in ../pruebas/simular_supabase.sql INSTALAR_TODO.sql 900_datos_ejemplo.sql ../pruebas/usuarios_prueba.sql; do $P -d taller -f "$f"; done
rm -rf /tmp/archivos_prueba

# Reinicia PostgREST para que lea las funciones nuevas
pkill -x postgrest || true
sleep 1
(cd "$DIR" && nohup /tmp/postgrest postgrest.conf > /tmp/pgrst.log 2>&1 &)
sleep 2
echo "Base de pruebas lista."
