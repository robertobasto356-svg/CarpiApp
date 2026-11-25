-- =====================================================================
-- CarpiApp · Almacenamiento (Supabase Storage)
-- Rutas:
--   fotos/        {carpinteria_id}/{pedido_id}/{archivo}   privado
--   cotizaciones/ {carpinteria_id}/{pedido_id}/{archivo}   privado (PDF)
--   mensajes/     {carpinteria_id}/{cliente_perfil_id}/{archivo} privado
--   catalogo/     {carpinteria_id}/{archivo}               público
--   avatares/     {usuario_id}/{archivo}                   público
--   modelos/      {archivo}.glb | .usdz                    público, solo lectura
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('fotos',        'fotos',        false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
  ('cotizaciones', 'cotizaciones', false,  5242880, array['application/pdf']),
  ('mensajes',     'mensajes',     false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
  ('catalogo',     'catalogo',     true,   5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('avatares',     'avatares',     true,   2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('modelos',      'modelos',      true,  20971520, array['model/gltf-binary', 'model/vnd.usdz+zip', 'application/octet-stream'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ¿La ruta {carpinteria}/{pedido}/... corresponde a un pedido que puedo ver?
create or replace function privado.puede_usar_ruta_pedido(p_name text)
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
    where p.carpinteria_id::text = (storage.foldername(p_name))[1]
      and p.id::text = (storage.foldername(p_name))[2]
      and (k.propietario_id = (select auth.uid()) or c.perfil_id = (select auth.uid()))
  );
$$;

revoke execute on function privado.puede_usar_ruta_pedido(text) from public, anon;
grant execute on function privado.puede_usar_ruta_pedido(text) to authenticated, service_role;

-- Fotos de pedidos: carpintero y cliente del pedido
create policy "fotos: ver" on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and privado.puede_usar_ruta_pedido(name));
create policy "fotos: subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and privado.puede_usar_ruta_pedido(name));
create policy "fotos: reemplazar propias" on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and owner_id = (select auth.uid())::text)
  with check (bucket_id = 'fotos' and privado.puede_usar_ruta_pedido(name));
create policy "fotos: borrar propias" on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and owner_id = (select auth.uid())::text);

-- PDFs de cotización: el cliente lee; solo la carpintería escribe
create policy "cotizaciones: ver" on storage.objects for select to authenticated
  using (bucket_id = 'cotizaciones' and privado.puede_usar_ruta_pedido(name));
create policy "cotizaciones: subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'cotizaciones'
              and (storage.foldername(name))[1] = (select privado.mi_carpinteria())::text
              and privado.puede_usar_ruta_pedido(name));
create policy "cotizaciones: reemplazar" on storage.objects for update to authenticated
  using (bucket_id = 'cotizaciones' and (storage.foldername(name))[1] = (select privado.mi_carpinteria())::text)
  with check (bucket_id = 'cotizaciones' and (storage.foldername(name))[1] = (select privado.mi_carpinteria())::text);
create policy "cotizaciones: borrar" on storage.objects for delete to authenticated
  using (bucket_id = 'cotizaciones' and (storage.foldername(name))[1] = (select privado.mi_carpinteria())::text);

-- Fotos del chat: la carpintería y el cliente de esa conversación
create policy "mensajes: ver" on storage.objects for select to authenticated
  using (bucket_id = 'mensajes'
         and ((storage.foldername(name))[1] = (select privado.mi_carpinteria())::text
              or (storage.foldername(name))[2] = (select auth.uid())::text));
create policy "mensajes: subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'mensajes'
              and ((storage.foldername(name))[1] = (select privado.mi_carpinteria())::text
                   or (storage.foldername(name))[2] = (select auth.uid())::text));

-- Catálogo: público; cada carpintería gestiona su carpeta
create policy "catalogo: ver" on storage.objects for select to authenticated
  using (bucket_id = 'catalogo');
create policy "catalogo: subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'catalogo' and (storage.foldername(name))[1] = (select privado.mi_carpinteria())::text);
create policy "catalogo: reemplazar" on storage.objects for update to authenticated
  using (bucket_id = 'catalogo' and (storage.foldername(name))[1] = (select privado.mi_carpinteria())::text)
  with check (bucket_id = 'catalogo' and (storage.foldername(name))[1] = (select privado.mi_carpinteria())::text);
create policy "catalogo: borrar" on storage.objects for delete to authenticated
  using (bucket_id = 'catalogo' and (storage.foldername(name))[1] = (select privado.mi_carpinteria())::text);

-- Avatares: cada usuario su carpeta
create policy "avatares: ver" on storage.objects for select to authenticated
  using (bucket_id = 'avatares');
create policy "avatares: subir" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatares' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatares: reemplazar" on storage.objects for update to authenticated
  using (bucket_id = 'avatares' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatares' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatares: borrar" on storage.objects for delete to authenticated
  using (bucket_id = 'avatares' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Modelos 3D de referencia (solo lectura para la app)
create policy "modelos: ver" on storage.objects for select to authenticated
  using (bucket_id = 'modelos');
