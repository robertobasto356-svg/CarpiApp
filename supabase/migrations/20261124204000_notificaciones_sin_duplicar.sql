-- Evita notificaciones duplicadas: los cambios de estado que provoca una
-- cotización (cotizado, aceptado, rechazado, ajustes) ya los avisa el trigger
-- de cotizaciones; aquí solo se registran en el historial.
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
      if new.estado not in ('cotizado', 'aceptado', 'rechazado', 'ajustes_solicitados') then
        perform privado.notificar(v_cliente, new.titulo || ': ' || privado.etiqueta_estado(new.estado),
          'Tu pedido cambió de estado.', 'pedido', new.id);
        perform privado.notificar(v_duenio, new.titulo || ': ' || privado.etiqueta_estado(new.estado),
          'El cliente actualizó el pedido.', 'pedido', new.id);
      end if;
    elsif new.progreso is distinct from old.progreso then
      perform privado.notificar(v_cliente, new.titulo || ': avance ' || new.progreso || '%',
        'Tu carpintero actualizó el avance.', 'avance', new.id);
    end if;
  end if;
  return new;
end;
$$;
