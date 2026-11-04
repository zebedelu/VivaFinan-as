-- Fatia 1 - Task 1: extensoes e schema privado.
-- O projeto hospedado ja tem a migration `extensions` aplicada via MCP.
-- Este arquivo existe para que um reset do zero a partir do repo reproduza
-- o mesmo estado inicial.

create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
