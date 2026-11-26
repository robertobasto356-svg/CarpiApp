-- =====================================================================
-- Avance de fabricación con nota en un solo paso.
-- Antes: el disparador registraba "En fabricación" y la app agregaba otra
-- fila con la nota (dos entradas en el historial, y el aviso al cliente
-- no incluía la nota). Ahora la nota reemplaza el texto genérico del
-- avance y del aviso que el disparador crea en la misma transacción.
-- =====================================================================
create or replace function public.registrar_avance(
  p_pedido bigint,
  p_estado text,
  p_progreso int,
  p_entrega date default null,
  p_nota text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ped     public.pedidos;
  v_cliente uuid;
  v_nota    text := nullif(btrim(coalesce(p_nota, '')), '');
  v_prog    int := greatest(0, least(100, coalesce(p_progreso, 0)));
begin
  select p.* into v_ped
  from public.pedidos p
  where p.id = p_pedido and p.carpinteria_id = (select privado.mi_carpinteria());
  if v_ped.id is null then
    raise exception 'No tienes acceso a este pedido.' using errcode = '42501';
  end if;
  if p_estado not in ('en_fabricacion', 'por_entregar', 'entregado') then
    raise exception 'Estado de avance no válido.';
  end if;

  update public.pedidos
     set estado = p_estado, progreso = v_prog, fecha_entrega = p_entrega
   where id = p_pedido;

  if v_nota is null then
    return;
  end if;

  -- El disparador ya registró el cambio en esta transacción (mismo now()): le ponemos la nota.
  update public.avances a
     set nota = v_nota
   where a.id = (select x.id from public.avances x
                 where x.pedido_id = p_pedido and x.created_at = now()
                 order by x.id desc limit 1);
  if not found then
    insert into public.avances (pedido_id, estado, progreso, nota)
    values (p_pedido, p_estado, v_prog, v_nota);
  end if;

  select c.perfil_id into v_cliente from public.clientes c where c.id = v_ped.cliente_id;
  update public.notificaciones n
     set cuerpo = v_nota
   where n.pedido_id = p_pedido and n.usuario_id = v_cliente and n.created_at = now();
  if not found then
    perform privado.notificar(v_cliente, v_ped.titulo || ': nueva nota de tu carpintero', v_nota, 'avance', p_pedido);
  end if;
end;
$$;

revoke execute on function public.registrar_avance(bigint, text, int, date, text) from public, anon;
grant execute on function public.registrar_avance(bigint, text, int, date, text) to authenticated;

-- =====================================================================
-- Calificar ahora avisa al carpintero.
-- =====================================================================
create or replace function public.calificar_pedido(p_pedido bigint, p_estrellas int, p_opinion text default '')
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_ped   public.pedidos;
  v_duenio uuid;
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

  select k.propietario_id into v_duenio from public.carpinterias k where k.id = v_ped.carpinteria_id;
  perform privado.notificar(v_duenio,
    'Calificación ' || repeat('★', greatest(1, least(5, p_estrellas))) || ': ' || v_ped.titulo,
    coalesce(nullif(btrim(p_opinion), ''), 'El cliente calificó el trabajo.'), 'pedido', p_pedido);
end;
$$;

-- =====================================================================
-- Avisos de visitas: el cliente se entera cuando el carpintero agenda,
-- confirma, reprograma o cancela; el carpintero, cuando el cliente cambia algo.
-- (notificar() nunca avisa a quien hizo el cambio.)
-- =====================================================================
create or replace function privado.cuando_texto(p_fecha timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select to_char(p_fecha at time zone 'America/Merida', 'DD/MM/YYYY "a las" FMHH12:MI')
      || case when extract(hour from p_fecha at time zone 'America/Merida') < 12 then ' a. m.' else ' p. m.' end;
$$;

create or replace function privado.al_cambiar_cita()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cliente uuid;
  v_duenio  uuid;
  v_titulo  text;
  v_detalle text := privado.cuando_texto(new.fecha_hora)
                    || coalesce(' · ' || nullif(btrim(new.direccion), ''), '');
begin
  select c.perfil_id into v_cliente from public.clientes c where c.id = new.cliente_id;
  select k.propietario_id into v_duenio from public.carpinterias k where k.id = new.carpinteria_id;

  if tg_op = 'INSERT' then
    -- La cita de una solicitud nueva ya genera el aviso "Nueva solicitud" al carpintero.
    perform privado.notificar(v_cliente, 'Visita agendada: ' || new.motivo, v_detalle, 'pedido', new.pedido_id);
    return new;
  end if;

  if new.estado is distinct from old.estado and new.estado in ('confirmada', 'cancelada') then
    v_titulo := case new.estado when 'confirmada' then 'Visita confirmada: ' else 'Visita cancelada: ' end || new.motivo;
  elsif new.fecha_hora is distinct from old.fecha_hora and new.estado <> 'cancelada' then
    v_titulo := 'Visita reprogramada: ' || new.motivo;
  else
    return new;
  end if;

  perform privado.notificar(v_cliente, v_titulo, v_detalle, 'pedido', new.pedido_id);
  perform privado.notificar(v_duenio, v_titulo, v_detalle, 'pedido', new.pedido_id);
  return new;
end;
$$;

drop trigger if exists citas_aviso on public.citas;
create trigger citas_aviso
  after insert or update of estado, fecha_hora on public.citas
  for each row execute function privado.al_cambiar_cita();

-- =====================================================================
-- El interruptor "Notificaciones" del perfil ahora se respeta.
-- =====================================================================
create or replace function privado.notificar(p_usuario uuid, p_titulo text, p_cuerpo text, p_tipo text, p_pedido bigint)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notificaciones (usuario_id, titulo, cuerpo, tipo, pedido_id)
  select p_usuario, p_titulo, p_cuerpo, p_tipo, p_pedido
  where p_usuario is not null
    and p_usuario is distinct from (select auth.uid())
    and coalesce((select p.notificaciones from public.perfiles p where p.id = p_usuario), true);
$$;
