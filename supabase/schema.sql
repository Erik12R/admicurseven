-- ============================================================
--  Esquema para "Panel de Curso"  (Supabase / PostgreSQL)
--  Ejecutar en: Supabase Dashboard -> SQL Editor -> New query
--  Es idempotente: puedes volver a correrlo sin romper nada.
-- ============================================================

-- ------------------------------------------------------------
-- 1) PERFILES (rol admin / editor / espectador) ligados a auth.users
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  nombre     text,
  role       text not null default 'editor' check (role in ('admin','editor','espectador')),
  created_at timestamptz not null default now()
);

-- Si la tabla ya existía con la restricción vieja, la actualizamos
-- (agrega el rol 'espectador').
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('admin','editor','espectador'));

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

-- Helper: ¿el usuario actual puede EDITAR? (admin o editor; los
-- 'espectador' solo pueden leer)
create or replace function public.can_edit()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin','editor')
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
  estado      text not null default 'por realizar' check (estado in ('por realizar','finalizado')),
  created_by  uuid default auth.uid() references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);

-- Migración del estado de deberes (bases ya existentes):
-- los estados viejos ('pendiente'/'hecho') pasan a 'por realizar'/'finalizado'.
alter table public.deberes drop constraint if exists deberes_estado_check;
update public.deberes set estado = 'por realizar' where estado = 'pendiente';
update public.deberes set estado = 'finalizado'  where estado = 'hecho';
alter table public.deberes alter column estado set default 'por realizar';
alter table public.deberes add constraint deberes_estado_check
  check (estado in ('por realizar','finalizado'));

-- Marca como 'finalizado' los deberes cuya fecha de entrega ya pasó.
-- Es SECURITY DEFINER para que cualquier usuario con sesión pueda
-- dispararla (la página la llama al cargar) sin necesidad de permiso de edición.
create or replace function public.finalizar_deberes()
returns void
language sql
security definer
set search_path = public
as $$
  update public.deberes
     set estado = 'finalizado'
   where estado <> 'finalizado'
     and entrega is not null
     and entrega < current_date;
$$;

grant execute on function public.finalizar_deberes() to authenticated;

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

-- ------------------------------------------------------------
-- 3) PERMISOS (RLS) de las tablas del curso
-- ------------------------------------------------------------
--   * SELECT: cualquier usuario autenticado (admin, editor, espectador)
--   * INSERT/UPDATE/DELETE: solo admin y editor (los espectadores NO editan)
do $$
declare t text;
begin
  foreach t in array array['eventos','deberes','pruebas','finanzas']
  loop
    execute format('alter table public.%I enable row level security;', t);

    -- limpia políticas anteriores (permisos totales) si existían
    execute format('drop policy if exists "%s_editor_access" on public.%I;', t, t);
    execute format('drop policy if exists "%s_read" on public.%I;', t, t);
    execute format('drop policy if exists "%s_insert" on public.%I;', t, t);
    execute format('drop policy if exists "%s_update" on public.%I;', t, t);
    execute format('drop policy if exists "%s_delete" on public.%I;', t, t);

    execute format('create policy "%s_read" on public.%I '
      'for select to authenticated using (true);', t, t);

    execute format('create policy "%s_insert" on public.%I '
      'for insert to authenticated with check (public.can_edit());', t, t);

    execute format('create policy "%s_update" on public.%I '
      'for update to authenticated using (public.can_edit()) with check (public.can_edit());', t, t);

    execute format('create policy "%s_delete" on public.%I '
      'for delete to authenticated using (public.can_edit());', t, t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 4) TIEMPO REAL (que los cambios se vean sin recargar)
--    Agrega las tablas a la publicación de Realtime (idempotente).
-- ------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['eventos','deberes','pruebas','finanzas','profiles']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I;', t);
    end if;
  end loop;
end $$;

-- ------------------------------------------------------------
-- 5) NOTA IMPORTANTE (hacer una sola vez, como admin)
--    El primer usuario que crees se registra como 'editor'.
--    Para volverte ADMIN, corre:
--
--    update public.profiles set role = 'admin'
--    where email = 'TU_CORREO@ejemplo.com';
--
--    Roles disponibles:
--      admin       -> todo (incluye la pestaña Equipo)
--      editor      -> ver y editar el contenido del curso
--      espectador  -> SOLO ver (no puede crear, editar ni borrar)
--
--    Y en Authentication -> Providers -> Email, DESACTIVA
--    "Allow new users to sign up" (asi solo tu creas cuentas).
-- ------------------------------------------------------------
