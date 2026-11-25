-- =====================================================================
-- CarpiApp · Esquema completo (varias carpinterías, roles carpintero/cliente)
-- Supabase · PostgreSQL 17
-- =====================================================================
-- Modelo:
--   * Cada usuario tiene un perfil con rol 'carpintero' o 'cliente'.
--   * Cada carpintero es dueño de una carpintería (se crea al registrarse).
--   * Los datos de trabajo (clientes, pedidos, citas, cotizaciones,
--     inventario, gastos...) pertenecen a una carpintería.
--   * Un cliente con cuenta ve solo sus pedidos, cotizaciones y mensajes.
-- Seguridad: RLS en todas las tablas; funciones auxiliares en el esquema
-- privado (no expuesto por la API).
-- =====================================================================

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

create schema if not exists privado;
grant usage on schema privado to authenticated, service_role;

-- ---------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------
create or replace function privado.tocar_actualizado()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Texto sin acentos y en minúsculas (inmutable para índices de búsqueda)
create or replace function privado.normalizar(texto text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(texto, '')));
$$;

-- =====================================================================
-- 1. Perfiles y carpinterías
-- =====================================================================
create table public.perfiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  rol            text not null check (rol in ('carpintero', 'cliente')),
  nombre         text not null default '',
  telefono       text not null default '',
  direccion      text not null default '',
  ciudad         text not null default 'Mérida',
  rfc            text not null default '',
  metodo_pago    text not null default '',
  notificaciones boolean not null default true,
  avatar_path    text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
comment on table public.perfiles is 'Datos de cada usuario de CarpiApp y su rol.';

create table public.carpinterias (
  id             uuid primary key default gen_random_uuid(),
  propietario_id uuid not null unique references public.perfiles (id) on delete cascade,
  nombre         text not null,
  descripcion    text not null default '',
  telefono       text not null default '',
  correo         text not null default '',
  direccion      text not null default '',
  ciudad         text not null default 'Mérida',
  logo_path      text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
comment on table public.carpinterias is 'Taller de cada carpintero. Visible para todos los usuarios.';

-- =====================================================================
-- 2. Funciones auxiliares de seguridad (esquema privado)
-- =====================================================================
create or replace function privado.mi_carpinteria()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select c.id from public.carpinterias c where c.propietario_id = (select auth.uid());
$$;

create or replace function privado.es_carpintero()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.perfiles p
    where p.id = (select auth.uid()) and p.rol = 'carpintero'
  );
$$;

-- =====================================================================
-- 3. Clientes (agenda de cada carpintería)
-- =====================================================================
create table public.clientes (
  id             bigint generated always as identity primary key,
  carpinteria_id uuid not null references public.carpinterias (id) on delete cascade,
  perfil_id      uuid references public.perfiles (id) on delete set null,
  nombre         text not null,
  telefono       text not null default '',
  correo         text not null default '',
  direccion      text not null default '',
  notas          text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (carpinteria_id, perfil_id)
);
comment on table public.clientes is 'Clientes de una carpintería. perfil_id enlaza al cliente si tiene cuenta.';
create index clientes_carpinteria_idx on public.clientes (carpinteria_id);
create index clientes_perfil_idx on public.clientes (perfil_id);

create or replace function privado.mis_clientes()
returns setof bigint
language sql
stable
security definer
set search_path = ''
as $$
  select c.id from public.clientes c where c.perfil_id = (select auth.uid());
$$;

-- =====================================================================
-- 4. Catálogo y favoritos
-- =====================================================================
create table public.catalogo (
  id             bigint generated always as identity primary key,
  carpinteria_id uuid not null references public.carpinterias (id) on delete cascade,
  titulo         text not null,
  tipo_mueble    text not null,
  material       text not null default '',
  descripcion    text not null default '',
  precio_desde   numeric(12, 2) check (precio_desde is null or precio_desde >= 0),
  imagen_path    text,
  modelo_3d      text,
  publicado      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index catalogo_carpinteria_idx on public.catalogo (carpinteria_id);
create index catalogo_tipo_idx on public.catalogo (tipo_mueble) where publicado;

create table public.favoritos (
  perfil_id   uuid not null references public.perfiles (id) on delete cascade,
  catalogo_id bigint not null references public.catalogo (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (perfil_id, catalogo_id)
);
create index favoritos_catalogo_idx on public.favoritos (catalogo_id);

-- =====================================================================
-- 5. Pedidos (solicitud → cita → cotización → fabricación → entrega)
-- =====================================================================
create table public.pedidos (
  id                    bigint generated always as identity primary key,
  carpinteria_id        uuid not null references public.carpinterias (id) on delete cascade,
  cliente_id            bigint not null references public.clientes (id) on delete cascade,
  catalogo_id           bigint references public.catalogo (id) on delete set null,
  titulo                text not null,
  tipo_mueble           text not null,
  material_acabado      text not null default '',
  descripcion           text not null default '',
  estado                text not null default 'solicitado' check (estado in (
                          'solicitado', 'cita_agendada', 'en_cotizacion', 'cotizado',
                          'ajustes_solicitados', 'aceptado', 'en_fabricacion',
                          'por_entregar', 'entregado', 'rechazado', 'cancelado')),
  progreso              int not null default 0 check (progreso between 0 and 100),
  alto_cm               numeric(8, 2) check (alto_cm is null or alto_cm > 0),
  ancho_cm              numeric(8, 2) check (ancho_cm is null or ancho_cm > 0),
  fondo_cm              numeric(8, 2) check (fondo_cm is null or fondo_cm > 0),
  medidas_notas         text not null default '',
  medidas_registradas_at timestamptz,
  fecha_entrega         date,
  creado_por            uuid references public.perfiles (id) on delete set null default auth.uid(),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
comment on table public.pedidos is 'Cada mueble solicitado/fabricado. Las medidas las registra el carpintero en la cita.';
create index pedidos_carpinteria_estado_idx on public.pedidos (carpinteria_id, estado);
create index pedidos_cliente_idx on public.pedidos (cliente_id);
create index pedidos_catalogo_idx on public.pedidos (catalogo_id);
create index pedidos_creado_por_idx on public.pedidos (creado_por);

create or replace function privado.puede_ver_pedido(p_pedido bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.pedidos p
    join public.carpinterias k on k.id = p.carpinteria_id
    left join public.clientes c on c.id = p.cliente_id
    where p.id = p_pedido
      and (k.propietario_id = (select auth.uid()) or c.perfil_id = (select auth.uid()))
  );
$$;

-- Citas / visitas
create table public.citas (
  id             bigint generated always as identity primary key,
  carpinteria_id uuid not null references public.carpinterias (id) on delete cascade,
  cliente_id     bigint references public.clientes (id) on delete set null,
  pedido_id      bigint references public.pedidos (id) on delete cascade,
  fecha_hora     timestamptz not null,
  motivo         text not null default 'Toma de medidas',
  direccion      text not null default '',
  estado         text not null default 'confirmada'
                   check (estado in ('propuesta', 'confirmada', 'realizada', 'cancelada')),
  notas          text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index citas_carpinteria_fecha_idx on public.citas (carpinteria_id, fecha_hora);
create index citas_cliente_idx on public.citas (cliente_id);
create index citas_pedido_idx on public.citas (pedido_id);

-- Cotizaciones
create table public.cotizaciones (
  id                 bigint generated always as identity primary key,
  pedido_id          bigint not null references public.pedidos (id) on delete cascade,
  carpinteria_id     uuid not null references public.carpinterias (id) on delete cascade,
  costo_materiales   numeric(12, 2) not null default 0 check (costo_materiales >= 0),
  mano_obra          numeric(12, 2) not null default 0 check (mano_obra >= 0),
  costos_adicionales numeric(12, 2) not null default 0 check (costos_adicionales >= 0),
  total              numeric(12, 2) generated always as (costo_materiales + mano_obra + costos_adicionales) stored,
  notas              text not null default '',
  estado             text not null default 'borrador'
                       check (estado in ('borrador', 'enviada', 'aceptada', 'rechazada', 'ajustes')),
  comentario_cliente text not null default '',
  pdf_path           text,
  enviada_at         timestamptz,
  respondida_at      timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index cotizaciones_pedido_idx on public.cotizaciones (pedido_id);
create index cotizaciones_carpinteria_idx on public.cotizaciones (carpinteria_id, estado);

create table public.cotizacion_partidas (
  id              bigint generated always as identity primary key,
  cotizacion_id   bigint not null references public.cotizaciones (id) on delete cascade,
  concepto        text not null,
  cantidad        numeric(12, 3) not null default 1 check (cantidad > 0),
  unidad          text not null default 'pza',
  precio_unitario numeric(12, 2) not null default 0 check (precio_unitario >= 0),
  importe         numeric(14, 2) generated always as (round(cantidad * precio_unitario, 2)) stored,
  created_at      timestamptz not null default now()
);
create index partidas_cotizacion_idx on public.cotizacion_partidas (cotizacion_id);

-- Historial de avance del pedido
create table public.avances (
  id         bigint generated always as identity primary key,
  pedido_id  bigint not null references public.pedidos (id) on delete cascade,
  estado     text not null,
  progreso   int not null default 0,
  nota       text not null default '',
  autor_id   uuid references public.perfiles (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);
create index avances_pedido_idx on public.avances (pedido_id, created_at);
create index avances_autor_idx on public.avances (autor_id);

-- Fotos (referencias del cliente, evidencias del carpintero, vistas AR)
create table public.fotos (
  id             bigint generated always as identity primary key,
  pedido_id      bigint not null references public.pedidos (id) on delete cascade,
  autor_id       uuid references public.perfiles (id) on delete set null default auth.uid(),
  path           text not null,
  tipo           text not null default 'referencia' check (tipo in ('referencia', 'avance', 'vista_ar')),
  descripcion    text not null default '',
  descripcion_ia text not null default '',
  created_at     timestamptz not null default now()
);
create index fotos_pedido_idx on public.fotos (pedido_id);
create index fotos_autor_idx on public.fotos (autor_id);

-- =====================================================================
-- 6. Taller: proveedores, inventario y gastos
-- =====================================================================
create table public.proveedores (
  id             bigint generated always as identity primary key,
  carpinteria_id uuid references public.carpinterias (id) on delete cascade, -- null = directorio general
  tipo           text not null check (tipo in ('materiales', 'herramientas')),
  nombre         text not null,
  descripcion    text not null default '',
  telefono       text not null default '',
  whatsapp       text not null default '',
  correo         text not null default '',
  sitio_web      text not null default '',
  direccion      text not null default '',
  horario        text not null default '',
  ciudad         text not null default 'Mérida',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index proveedores_carpinteria_idx on public.proveedores (carpinteria_id, tipo);

create table public.inventario (
  id             bigint generated always as identity primary key,
  carpinteria_id uuid not null references public.carpinterias (id) on delete cascade,
  tipo           text not null check (tipo in ('material', 'herramienta')),
  nombre         text not null,
  categoria      text not null default '',
  unidad         text not null default 'pza',
  cantidad       numeric(12, 3) not null default 0 check (cantidad >= 0),
  costo_unitario numeric(12, 2) not null default 0 check (costo_unitario >= 0),
  stock_minimo   numeric(12, 3) not null default 0 check (stock_minimo >= 0),
  proveedor_id   bigint references public.proveedores (id) on delete set null,
  notas          text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index inventario_carpinteria_idx on public.inventario (carpinteria_id, tipo);
create index inventario_proveedor_idx on public.inventario (proveedor_id);

create table public.gastos (
  id             bigint generated always as identity primary key,
  carpinteria_id uuid not null references public.carpinterias (id) on delete cascade,
  concepto       text not null,
  categoria      text not null default 'General',
  monto          numeric(12, 2) not null check (monto > 0),
  fecha          date not null default current_date,
  pedido_id      bigint references public.pedidos (id) on delete set null,
  created_at     timestamptz not null default now()
);
create index gastos_carpinteria_fecha_idx on public.gastos (carpinteria_id, fecha);
create index gastos_pedido_idx on public.gastos (pedido_id);

-- =====================================================================
-- 7. Comunicación: mensajes, calificaciones y notificaciones
-- =====================================================================
create table public.mensajes (
  id                bigint generated always as identity primary key,
  carpinteria_id    uuid not null references public.carpinterias (id) on delete cascade,
  cliente_perfil_id uuid not null references public.perfiles (id) on delete cascade,
  autor_id          uuid not null references public.perfiles (id) on delete cascade default auth.uid(),
  texto             text not null default '',
  foto_path         text,
  leido             boolean not null default false,
  created_at        timestamptz not null default now(),
  check (length(texto) > 0 or foto_path is not null)
);
create index mensajes_conversacion_idx on public.mensajes (carpinteria_id, cliente_perfil_id, created_at);
create index mensajes_cliente_idx on public.mensajes (cliente_perfil_id);
create index mensajes_autor_idx on public.mensajes (autor_id);

create table public.calificaciones (
  pedido_id         bigint primary key references public.pedidos (id) on delete cascade,
  carpinteria_id    uuid not null references public.carpinterias (id) on delete cascade,
  cliente_perfil_id uuid not null references public.perfiles (id) on delete cascade default auth.uid(),
  estrellas         int not null check (estrellas between 1 and 5),
  opinion           text not null default '',
  created_at        timestamptz not null default now()
);
create index calificaciones_carpinteria_idx on public.calificaciones (carpinteria_id);
create index calificaciones_cliente_idx on public.calificaciones (cliente_perfil_id);

create table public.notificaciones (
  id         bigint generated always as identity primary key,
  usuario_id uuid not null references public.perfiles (id) on delete cascade,
  titulo     text not null,
  cuerpo     text not null default '',
  tipo       text not null default 'general',
  pedido_id  bigint references public.pedidos (id) on delete cascade,
  leida      boolean not null default false,
  created_at timestamptz not null default now()
);
create index notificaciones_usuario_idx on public.notificaciones (usuario_id, leida, created_at desc);
create index notificaciones_pedido_idx on public.notificaciones (pedido_id);

-- =====================================================================
-- 8. Base de conocimiento de CarpiIA (búsqueda en español)
-- =====================================================================
create table public.conocimiento (
  id         bigint generated always as identity primary key,
  categoria  text not null check (categoria in ('madera', 'tablero', 'acabado', 'herraje', 'herramienta', 'cuidado', 'proceso', 'app')),
  titulo     text not null,
  contenido  text not null,
  etiquetas  text not null default '',
  publico    text not null default 'ambos' check (publico in ('ambos', 'carpintero', 'cliente')),
  fuente     text not null default '',
  busqueda   tsvector generated always as (
               setweight(to_tsvector('spanish', privado.normalizar(titulo)), 'A') ||
               setweight(to_tsvector('spanish', privado.normalizar(etiquetas)), 'A') ||
               setweight(to_tsvector('spanish', privado.normalizar(contenido)), 'B')
             ) stored,
  created_at timestamptz not null default now()
);
create index conocimiento_busqueda_idx on public.conocimiento using gin (busqueda);
create index conocimiento_titulo_trgm_idx on public.conocimiento using gin (privado.normalizar(titulo) extensions.gin_trgm_ops);

-- =====================================================================
-- 9. Triggers de updated_at
-- =====================================================================
create trigger perfiles_actualizado before update on public.perfiles
  for each row execute function privado.tocar_actualizado();
create trigger carpinterias_actualizado before update on public.carpinterias
  for each row execute function privado.tocar_actualizado();
create trigger clientes_actualizado before update on public.clientes
  for each row execute function privado.tocar_actualizado();
create trigger catalogo_actualizado before update on public.catalogo
  for each row execute function privado.tocar_actualizado();
create trigger pedidos_actualizado before update on public.pedidos
  for each row execute function privado.tocar_actualizado();
create trigger citas_actualizado before update on public.citas
  for each row execute function privado.tocar_actualizado();
create trigger cotizaciones_actualizado before update on public.cotizaciones
  for each row execute function privado.tocar_actualizado();
create trigger proveedores_actualizado before update on public.proveedores
  for each row execute function privado.tocar_actualizado();
create trigger inventario_actualizado before update on public.inventario
  for each row execute function privado.tocar_actualizado();

-- =====================================================================
-- 10. Alta automática de perfil (y carpintería) al registrarse
-- =====================================================================
create or replace function privado.nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rol    text := coalesce(new.raw_user_meta_data ->> 'tipo_cuenta', 'cliente');
  v_nombre text := coalesce(nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''), split_part(new.email, '@', 1));
  v_taller text := nullif(trim(new.raw_user_meta_data ->> 'nombre_carpinteria'), '');
begin
  if v_rol not in ('carpintero', 'cliente') then
    v_rol := 'cliente';
  end if;

  insert into public.perfiles (id, rol, nombre, telefono)
  values (new.id, v_rol, v_nombre, coalesce(new.raw_user_meta_data ->> 'telefono', ''))
  on conflict (id) do nothing;

  if v_rol = 'carpintero' then
    insert into public.carpinterias (propietario_id, nombre, telefono, correo)
    values (new.id, coalesce(v_taller, 'Carpintería de ' || v_nombre),
            coalesce(new.raw_user_meta_data ->> 'telefono', ''), coalesce(new.email, ''))
    on conflict (propietario_id) do nothing;
  end if;

  return new;
end;
$$;

create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function privado.nuevo_usuario();

-- =====================================================================
-- 11. Notificaciones y avances automáticos
-- =====================================================================
create or replace function privado.notificar(p_usuario uuid, p_titulo text, p_cuerpo text, p_tipo text, p_pedido bigint)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notificaciones (usuario_id, titulo, cuerpo, tipo, pedido_id)
  select p_usuario, p_titulo, p_cuerpo, p_tipo, p_pedido
  where p_usuario is not null and p_usuario is distinct from (select auth.uid());
$$;

create or replace function privado.etiqueta_estado(p_estado text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_estado
    when 'solicitado' then 'Solicitud recibida'
    when 'cita_agendada' then 'Cita agendada'
    when 'en_cotizacion' then 'En cotización'
    when 'cotizado' then 'Cotización enviada'
    when 'ajustes_solicitados' then 'Ajustes solicitados'
    when 'aceptado' then 'Cotización aceptada'
    when 'en_fabricacion' then 'En fabricación'
    when 'por_entregar' then 'Listo para entregar'
    when 'entregado' then 'Entregado'
    when 'rechazado' then 'Rechazado'
    when 'cancelado' then 'Cancelado'
    else p_estado
  end;
$$;

create or replace function privado.al_cambiar_pedido()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cliente uuid;
  v_duenio  uuid;
begin
  select c.perfil_id into v_cliente from public.clientes c where c.id = new.cliente_id;
  select k.propietario_id into v_duenio from public.carpinterias k where k.id = new.carpinteria_id;

  if tg_op = 'INSERT' then
    insert into public.avances (pedido_id, estado, progreso, nota)
    values (new.id, new.estado, new.progreso, 'Pedido creado');
    perform privado.notificar(v_duenio, 'Nueva solicitud: ' || new.titulo,
      'Un cliente solicitó una cotización.', 'pedido', new.id);
    return new;
  end if;

  if new.estado is distinct from old.estado or new.progreso is distinct from old.progreso then
    insert into public.avances (pedido_id, estado, progreso, nota)
    values (new.id, new.estado, new.progreso, privado.etiqueta_estado(new.estado));
    if new.estado is distinct from old.estado then
      perform privado.notificar(v_cliente, new.titulo || ': ' || privado.etiqueta_estado(new.estado),
        'Tu pedido cambió de estado.', 'pedido', new.id);
      perform privado.notificar(v_duenio, new.titulo || ': ' || privado.etiqueta_estado(new.estado),
        'El cliente actualizó el pedido.', 'pedido', new.id);
    elsif new.progreso is distinct from old.progreso then
      perform privado.notificar(v_cliente, new.titulo || ': avance ' || new.progreso || '%',
        'Tu carpintero actualizó el avance.', 'avance', new.id);
    end if;
  end if;
  return new;
end;
$$;

create trigger pedidos_historial
  after insert or update on public.pedidos
  for each row execute function privado.al_cambiar_pedido();

create or replace function privado.al_cambiar_cotizacion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cliente uuid;
  v_duenio  uuid;
  v_titulo  text;
begin
  select c.perfil_id, k.propietario_id, p.titulo
    into v_cliente, v_duenio, v_titulo
  from public.pedidos p
  join public.clientes c on c.id = p.cliente_id
  join public.carpinterias k on k.id = p.carpinteria_id
  where p.id = new.pedido_id;

  if new.estado is distinct from coalesce(old.estado, '') then
    if new.estado = 'enviada' then
      perform privado.notificar(v_cliente, 'Cotización lista: ' || v_titulo,
        'Total $' || to_char(new.total, 'FM999,999,990.00') || '. Revísala y respóndela.', 'cotizacion', new.pedido_id);
    elsif new.estado in ('aceptada', 'rechazada', 'ajustes') then
      perform privado.notificar(v_duenio, 'Cotización ' || new.estado || ': ' || v_titulo,
        coalesce(nullif(new.comentario_cliente, ''), 'El cliente respondió tu cotización.'), 'cotizacion', new.pedido_id);
    end if;
  end if;
  return new;
end;
$$;

create trigger cotizaciones_aviso
  after insert or update of estado on public.cotizaciones
  for each row execute function privado.al_cambiar_cotizacion();

-- El costo de materiales se calcula con las partidas
create or replace function privado.recalcular_materiales()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cot bigint := coalesce(new.cotizacion_id, old.cotizacion_id);
begin
  update public.cotizaciones q
     set costo_materiales = coalesce((select sum(p.importe) from public.cotizacion_partidas p where p.cotizacion_id = v_cot), 0)
   where q.id = v_cot;
  return null;
end;
$$;

create trigger partidas_recalcular
  after insert or update or delete on public.cotizacion_partidas
  for each row execute function privado.recalcular_materiales();

create or replace function privado.al_nuevo_mensaje()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_duenio uuid;
  v_taller text;
  v_cliente text;
begin
  select k.propietario_id, k.nombre into v_duenio, v_taller from public.carpinterias k where k.id = new.carpinteria_id;
  select p.nombre into v_cliente from public.perfiles p where p.id = new.cliente_perfil_id;
  if new.autor_id = new.cliente_perfil_id then
    perform privado.notificar(v_duenio, 'Mensaje de ' || coalesce(v_cliente, 'un cliente'),
      left(coalesce(nullif(new.texto, ''), '📷 Foto'), 120), 'mensaje', null);
  else
    perform privado.notificar(new.cliente_perfil_id, 'Mensaje de ' || coalesce(v_taller, 'tu carpintero'),
      left(coalesce(nullif(new.texto, ''), '📷 Foto'), 120), 'mensaje', null);
  end if;
  return new;
end;
$$;

create trigger mensajes_aviso
  after insert on public.mensajes
  for each row execute function privado.al_nuevo_mensaje();

-- =====================================================================
-- 12. Funciones RPC para el cliente (validan identidad y transiciones)
-- =====================================================================
create or replace function public.crear_solicitud(
  p_carpinteria uuid,
  p_tipo_mueble text,
  p_titulo text,
  p_material_acabado text,
  p_descripcion text,
  p_fecha_cita timestamptz,
  p_direccion text,
  p_catalogo bigint default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := (select auth.uid());
  v_perfil  public.perfiles;
  v_cliente bigint;
  v_pedido  bigint;
begin
  select * into v_perfil from public.perfiles where id = v_uid;
  if v_perfil.id is null or v_perfil.rol <> 'cliente' then
    raise exception 'Solo los clientes pueden enviar solicitudes.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.carpinterias where id = p_carpinteria) then
    raise exception 'La carpintería no existe.';
  end if;
  if coalesce(trim(p_tipo_mueble), '') = '' then
    raise exception 'Elige el tipo de mueble.';
  end if;
  if p_fecha_cita is not null and p_fecha_cita < now() then
    raise exception 'La fecha de la cita debe ser futura.';
  end if;

  insert into public.clientes as c (carpinteria_id, perfil_id, nombre, telefono, correo, direccion)
  values (p_carpinteria, v_uid, v_perfil.nombre, v_perfil.telefono,
          coalesce((select u.email from auth.users u where u.id = v_uid), ''),
          coalesce(nullif(p_direccion, ''), v_perfil.direccion))
  on conflict (carpinteria_id, perfil_id) do update
     set nombre = excluded.nombre,
         direccion = case when excluded.direccion <> '' then excluded.direccion else c.direccion end
  returning c.id into v_cliente;

  insert into public.pedidos (carpinteria_id, cliente_id, catalogo_id, titulo, tipo_mueble,
                              material_acabado, descripcion, estado, creado_por)
  values (p_carpinteria, v_cliente, p_catalogo,
          coalesce(nullif(trim(p_titulo), ''), p_tipo_mueble), p_tipo_mueble,
          coalesce(p_material_acabado, ''), coalesce(p_descripcion, ''),
          case when p_fecha_cita is null then 'solicitado' else 'cita_agendada' end, v_uid)
  returning id into v_pedido;

  if p_fecha_cita is not null then
    insert into public.citas (carpinteria_id, cliente_id, pedido_id, fecha_hora, motivo, direccion, estado)
    values (p_carpinteria, v_cliente, v_pedido, p_fecha_cita, 'Toma de medidas',
            coalesce(nullif(p_direccion, ''), v_perfil.direccion), 'propuesta');
  end if;

  return v_pedido;
end;
$$;

create or replace function public.responder_cotizacion(
  p_cotizacion bigint,
  p_respuesta text,
  p_comentario text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_cot public.cotizaciones;
  v_estado_pedido text;
begin
  if p_respuesta not in ('aceptada', 'rechazada', 'ajustes') then
    raise exception 'Respuesta no válida.';
  end if;

  select q.* into v_cot
  from public.cotizaciones q
  join public.pedidos p on p.id = q.pedido_id
  join public.clientes c on c.id = p.cliente_id
  where q.id = p_cotizacion and c.perfil_id = v_uid;

  if v_cot.id is null then
    raise exception 'No tienes acceso a esta cotización.' using errcode = '42501';
  end if;
  if v_cot.estado <> 'enviada' then
    raise exception 'Esta cotización ya fue respondida.';
  end if;

  update public.cotizaciones
     set estado = p_respuesta,
         comentario_cliente = coalesce(p_comentario, ''),
         respondida_at = now()
   where id = p_cotizacion;

  v_estado_pedido := case p_respuesta
    when 'aceptada' then 'aceptado'
    when 'rechazada' then 'rechazado'
    else 'ajustes_solicitados' end;

  update public.pedidos set estado = v_estado_pedido where id = v_cot.pedido_id;
end;
$$;

create or replace function public.calificar_pedido(p_pedido bigint, p_estrellas int, p_opinion text default '')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_ped public.pedidos;
begin
  select p.* into v_ped
  from public.pedidos p join public.clientes c on c.id = p.cliente_id
  where p.id = p_pedido and c.perfil_id = v_uid;
  if v_ped.id is null then
    raise exception 'No tienes acceso a este pedido.' using errcode = '42501';
  end if;
  if v_ped.estado <> 'entregado' then
    raise exception 'Solo puedes calificar pedidos entregados.';
  end if;
  insert into public.calificaciones (pedido_id, carpinteria_id, cliente_perfil_id, estrellas, opinion)
  values (p_pedido, v_ped.carpinteria_id, v_uid, p_estrellas, coalesce(p_opinion, ''))
  on conflict (pedido_id) do update set estrellas = excluded.estrellas, opinion = excluded.opinion;
end;
$$;

-- Búsqueda en la base de conocimiento (texto completo en español + similitud)
create or replace function public.buscar_conocimiento(p_consulta text, p_publico text default 'ambos', p_limite int default 5)
returns table (id bigint, categoria text, titulo text, contenido text, fuente text, puntaje real)
language sql
stable
set search_path = ''
as $$
  -- Cualquier palabra de la consulta (OR) para no exigir que aparezcan todas
  with q as (
    select privado.normalizar(p_consulta) as texto,
           nullif(array_to_string(array(
             select quote_literal(l.lexeme)
             from unnest(to_tsvector('spanish', privado.normalizar(p_consulta))) as l
           ), ' | '), '')::tsquery as tsq
  )
  select k.id, k.categoria, k.titulo, k.contenido, k.fuente,
         (coalesce(ts_rank_cd(k.busqueda, q.tsq), 0) * 4
           + extensions.similarity(privado.normalizar(k.titulo), q.texto))::real as puntaje
  from public.conocimiento k, q
  where (k.publico = 'ambos' or k.publico = p_publico)
    and ((q.tsq is not null and k.busqueda @@ q.tsq)
         or extensions.similarity(privado.normalizar(k.titulo), q.texto) > 0.3)
  order by puntaje desc
  limit least(greatest(p_limite, 1), 10);
$$;

-- =====================================================================
-- 13. Row Level Security
-- =====================================================================
alter table public.perfiles            enable row level security;
alter table public.carpinterias        enable row level security;
alter table public.clientes            enable row level security;
alter table public.catalogo            enable row level security;
alter table public.favoritos           enable row level security;
alter table public.pedidos             enable row level security;
alter table public.citas               enable row level security;
alter table public.cotizaciones        enable row level security;
alter table public.cotizacion_partidas enable row level security;
alter table public.avances             enable row level security;
alter table public.fotos               enable row level security;
alter table public.proveedores         enable row level security;
alter table public.inventario          enable row level security;
alter table public.gastos              enable row level security;
alter table public.mensajes            enable row level security;
alter table public.calificaciones      enable row level security;
alter table public.notificaciones      enable row level security;
alter table public.conocimiento        enable row level security;

-- Perfiles: el propio, y los de mis clientes (si soy carpintero)
create policy "perfiles: ver propio y de mis clientes" on public.perfiles
  for select to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1 from public.clientes c
      where c.perfil_id = perfiles.id and c.carpinteria_id = (select privado.mi_carpinteria())
    )
  );
create policy "perfiles: editar propio" on public.perfiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Carpinterías: todos las ven; solo el dueño la edita
create policy "carpinterias: ver todas" on public.carpinterias
  for select to authenticated using (true);
create policy "carpinterias: crear la mía" on public.carpinterias
  for insert to authenticated
  with check (propietario_id = (select auth.uid()) and (select privado.es_carpintero()));
create policy "carpinterias: editar la mía" on public.carpinterias
  for update to authenticated
  using (propietario_id = (select auth.uid()))
  with check (propietario_id = (select auth.uid()));

-- Clientes
create policy "clientes: el carpintero gestiona los suyos" on public.clientes
  for all to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "clientes: el cliente ve su ficha" on public.clientes
  for select to authenticated
  using (perfil_id = (select auth.uid()));

-- Catálogo
create policy "catalogo: ver publicado o propio" on public.catalogo
  for select to authenticated
  using (publicado or carpinteria_id = (select privado.mi_carpinteria()));
create policy "catalogo: el carpintero gestiona el suyo" on public.catalogo
  for all to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));

-- Favoritos
create policy "favoritos: propios" on public.favoritos
  for all to authenticated
  using (perfil_id = (select auth.uid()))
  with check (perfil_id = (select auth.uid()));

-- Pedidos
create policy "pedidos: el carpintero gestiona los suyos" on public.pedidos
  for all to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "pedidos: el cliente ve los suyos" on public.pedidos
  for select to authenticated
  using (cliente_id in (select privado.mis_clientes()));

-- Citas
create policy "citas: el carpintero gestiona las suyas" on public.citas
  for all to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "citas: el cliente ve las suyas" on public.citas
  for select to authenticated
  using (cliente_id in (select privado.mis_clientes()));

-- Cotizaciones y partidas
create policy "cotizaciones: el carpintero gestiona las suyas" on public.cotizaciones
  for all to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "cotizaciones: el cliente ve las enviadas" on public.cotizaciones
  for select to authenticated
  using (estado <> 'borrador' and privado.puede_ver_pedido(pedido_id));

create policy "partidas: el carpintero gestiona las suyas" on public.cotizacion_partidas
  for all to authenticated
  using (exists (select 1 from public.cotizaciones q
                 where q.id = cotizacion_id and q.carpinteria_id = (select privado.mi_carpinteria())))
  with check (exists (select 1 from public.cotizaciones q
                 where q.id = cotizacion_id and q.carpinteria_id = (select privado.mi_carpinteria())));
create policy "partidas: el cliente ve las de cotizaciones enviadas" on public.cotizacion_partidas
  for select to authenticated
  using (exists (select 1 from public.cotizaciones q
                 where q.id = cotizacion_id and q.estado <> 'borrador' and privado.puede_ver_pedido(q.pedido_id)));

-- Avances
create policy "avances: ver si puedo ver el pedido" on public.avances
  for select to authenticated
  using (privado.puede_ver_pedido(pedido_id));
create policy "avances: el carpintero agrega notas" on public.avances
  for insert to authenticated
  with check (exists (select 1 from public.pedidos p
                      where p.id = pedido_id and p.carpinteria_id = (select privado.mi_carpinteria())));

-- Fotos
create policy "fotos: ver si puedo ver el pedido" on public.fotos
  for select to authenticated
  using (privado.puede_ver_pedido(pedido_id));
create policy "fotos: subir a mis pedidos" on public.fotos
  for insert to authenticated
  with check (autor_id = (select auth.uid()) and privado.puede_ver_pedido(pedido_id));
create policy "fotos: editar o borrar las mías" on public.fotos
  for update to authenticated
  using (autor_id = (select auth.uid()))
  with check (autor_id = (select auth.uid()));
create policy "fotos: borrar las mías" on public.fotos
  for delete to authenticated
  using (autor_id = (select auth.uid()));

-- Proveedores: directorio general + los propios (solo carpinteros)
create policy "proveedores: carpinteros ven general y propios" on public.proveedores
  for select to authenticated
  using ((select privado.es_carpintero())
         and (carpinteria_id is null or carpinteria_id = (select privado.mi_carpinteria())));
create policy "proveedores: gestionar propios" on public.proveedores
  for insert to authenticated
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "proveedores: editar propios" on public.proveedores
  for update to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "proveedores: borrar propios" on public.proveedores
  for delete to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()));

-- Inventario y gastos: solo la carpintería dueña
create policy "inventario: solo la carpintería" on public.inventario
  for all to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "gastos: solo la carpintería" on public.gastos
  for all to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));

-- Mensajes: conversación carpintería ↔ cliente
create policy "mensajes: ver mis conversaciones" on public.mensajes
  for select to authenticated
  using (cliente_perfil_id = (select auth.uid()) or carpinteria_id = (select privado.mi_carpinteria()));
create policy "mensajes: escribir en mis conversaciones" on public.mensajes
  for insert to authenticated
  with check (
    autor_id = (select auth.uid())
    and (cliente_perfil_id = (select auth.uid()) or carpinteria_id = (select privado.mi_carpinteria()))
  );
create policy "mensajes: marcar leídos" on public.mensajes
  for update to authenticated
  using (cliente_perfil_id = (select auth.uid()) or carpinteria_id = (select privado.mi_carpinteria()))
  with check (cliente_perfil_id = (select auth.uid()) or carpinteria_id = (select privado.mi_carpinteria()));

-- Calificaciones: visibles para todos (reputación); se crean por RPC
create policy "calificaciones: ver todas" on public.calificaciones
  for select to authenticated using (true);

-- Notificaciones: propias
create policy "notificaciones: ver propias" on public.notificaciones
  for select to authenticated using (usuario_id = (select auth.uid()));
create policy "notificaciones: marcar propias" on public.notificaciones
  for update to authenticated
  using (usuario_id = (select auth.uid()))
  with check (usuario_id = (select auth.uid()));
create policy "notificaciones: borrar propias" on public.notificaciones
  for delete to authenticated using (usuario_id = (select auth.uid()));

-- Conocimiento: lectura para usuarios con sesión
create policy "conocimiento: lectura" on public.conocimiento
  for select to authenticated using (true);

-- =====================================================================
-- 14. Permisos de la API (las tablas nuevas no se exponen solas)
-- =====================================================================
-- Nada para usuarios sin sesión; el perfil solo se edita en columnas permitidas
revoke all on all tables in schema public from anon;
revoke all on public.perfiles, public.calificaciones, public.conocimiento from authenticated;

grant select, insert, update, delete on
  public.carpinterias, public.clientes, public.catalogo, public.favoritos, public.pedidos,
  public.citas, public.cotizaciones, public.cotizacion_partidas, public.avances, public.fotos,
  public.proveedores, public.inventario, public.gastos, public.mensajes, public.notificaciones
  to authenticated;
grant select on public.perfiles, public.calificaciones, public.conocimiento to authenticated;
grant update (nombre, telefono, direccion, ciudad, rfc, metodo_pago, notificaciones, avatar_path)
  on public.perfiles to authenticated;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

-- Funciones: quitar el acceso por defecto y dar solo lo necesario
revoke execute on all functions in schema privado from public, anon;
grant execute on function
  privado.mi_carpinteria(), privado.es_carpintero(), privado.mis_clientes(),
  privado.puede_ver_pedido(bigint), privado.normalizar(text)
  to authenticated, service_role;

revoke execute on function public.crear_solicitud(uuid, text, text, text, text, timestamptz, text, bigint) from public, anon;
revoke execute on function public.responder_cotizacion(bigint, text, text) from public, anon;
revoke execute on function public.calificar_pedido(bigint, int, text) from public, anon;
revoke execute on function public.buscar_conocimiento(text, text, int) from public, anon;
grant execute on function public.crear_solicitud(uuid, text, text, text, text, timestamptz, text, bigint) to authenticated;
grant execute on function public.responder_cotizacion(bigint, text, text) to authenticated;
grant execute on function public.calificar_pedido(bigint, int, text) to authenticated;
grant execute on function public.buscar_conocimiento(text, text, int) to authenticated, service_role;

-- =====================================================================
-- 15. Tiempo real (mensajes, notificaciones y estado de pedidos)
-- =====================================================================
alter publication supabase_realtime add table public.mensajes, public.notificaciones, public.pedidos, public.cotizaciones;

-- =====================================================================
-- 16. Perfiles para usuarios que ya existían
-- =====================================================================
insert into public.perfiles (id, rol, nombre)
select u.id,
       case when u.raw_user_meta_data ->> 'tipo_cuenta' = 'carpintero' then 'carpintero' else 'cliente' end,
       coalesce(nullif(u.raw_user_meta_data ->> 'nombre', ''), split_part(u.email, '@', 1))
from auth.users u
on conflict (id) do nothing;

insert into public.carpinterias (propietario_id, nombre, correo)
select p.id, 'Carpintería de ' || p.nombre, coalesce(u.email, '')
from public.perfiles p join auth.users u on u.id = p.id
where p.rol = 'carpintero'
on conflict (propietario_id) do nothing;
