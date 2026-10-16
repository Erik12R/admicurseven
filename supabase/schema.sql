-- ============================================================
--  Esquema para "Panel de Curso"  (Supabase / PostgreSQL)
--  Ejecutar en: Supabase Dashboard -> SQL Editor -> New query
--  Es idempotente: puedes volver a correrlo sin romper nada.
-- ============================================================

-- ------------------------------------------------------------
-- 1) PERFILES (rol admin / editor) ligados a auth.users
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  nombre     text,
  role       text not null default 'editor' check (role in ('admin','editor')),
  created_at timestamptz not null default now()
);

-- Crea el perfil automaticamente cuando se crea un usuario.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, nombre, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'nombre', new.email),
    'editor'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper: ¿el usuario actual es admin?
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

alter table public.profiles enable row level security;

drop policy if exists "perfiles_lectura" on public.profiles;
create policy "perfiles_lectura" on public.profiles
  for select to authenticated using (true);

drop policy if exists "perfiles_update_admin" on public.profiles;
create policy "perfiles_update_admin" on public.profiles
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "perfiles_delete_admin" on public.profiles;
create policy "perfiles_delete_admin" on public.profiles
  for delete to authenticated using (public.is_admin());

-- ------------------------------------------------------------
-- 2) TABLAS DE DATOS DEL CURSO
--    (las pueden leer y editar todos los usuarios con sesion)
-- ------------------------------------------------------------
create table if not exists public.eventos (
  id          bigint generated always as identity primary key,
  titulo      text not null,
  descripcion text,
  inicio      date not null,
  fin         date,
  created_by  uuid default auth.uid() references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.deberes (
  id          bigint generated always as identity primary key,
  titulo      text not null,
  materia     text,
  descripcion text,
  entrega     date,
  estado      text not null default 'pendiente' check (estado in ('pendiente','hecho')),
  created_by  uuid default auth.uid() references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.pruebas (
  id          bigint generated always as identity primary key,
  titulo      text not null,
  materia     text,
  descripcion text,
  fecha       date,
  peso        numeric(6,2) default 0,
  nota        numeric(6,2),
  created_by  uuid default auth.uid() references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.finanzas (
  id          bigint generated always as identity primary key,
  fecha       date not null default current_date,
  concepto    text not null,
  estudiante  text,
  tipo        text not null default 'ingreso' check (tipo in ('ingreso','gasto')),
  monto       numeric(12,2) not null default 0,
  created_by  uuid default auth.uid() references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);

-- RLS: acceso total para usuarios autenticados (son los editores de confianza)
do $$
declare t text;
begin
  foreach t in array array['eventos','deberes','pruebas','finanzas']
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists "%s_editor_access" on public.%I;', t, t);
    execute format(
      'create policy "%s_editor_access" on public.%I '
      'for all to authenticated using (true) with check (true);', t, t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 3) NOTA IMPORTANTE (hacer una sola vez, como admin)
--    El primer usuario que crees se registra como 'editor'.
--    Para volverte ADMIN, corre:
--
--    update public.profiles set role = 'admin'
--    where email = 'TU_CORREO@ejemplo.com';
--
--    Y en Authentication -> Providers -> Email, DESACTIVA
--    "Allow new users to sign up" (asi solo tu creas cuentas).
-- ------------------------------------------------------------
