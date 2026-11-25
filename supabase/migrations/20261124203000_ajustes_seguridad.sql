-- =====================================================================
-- CarpiApp · Ajustes tras la revisión de advisors
--   * La función de la plataforma rls_auto_enable (event trigger) no debe
--     ser invocable por RPC.
--   * Una sola política SELECT por tabla (carpintero OR cliente) en lugar
--     de dos políticas permisivas, y políticas separadas para escribir.
-- =====================================================================

revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- clientes
drop policy "clientes: el carpintero gestiona los suyos" on public.clientes;
drop policy "clientes: el cliente ve su ficha" on public.clientes;
create policy "clientes: ver" on public.clientes for select to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()) or perfil_id = (select auth.uid()));
create policy "clientes: crear" on public.clientes for insert to authenticated
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "clientes: editar" on public.clientes for update to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "clientes: borrar" on public.clientes for delete to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()));

-- catalogo
drop policy "catalogo: ver publicado o propio" on public.catalogo;
drop policy "catalogo: el carpintero gestiona el suyo" on public.catalogo;
create policy "catalogo: ver" on public.catalogo for select to authenticated
  using (publicado or carpinteria_id = (select privado.mi_carpinteria()));
create policy "catalogo: crear" on public.catalogo for insert to authenticated
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "catalogo: editar" on public.catalogo for update to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "catalogo: borrar" on public.catalogo for delete to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()));

-- pedidos
drop policy "pedidos: el carpintero gestiona los suyos" on public.pedidos;
drop policy "pedidos: el cliente ve los suyos" on public.pedidos;
create policy "pedidos: ver" on public.pedidos for select to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()) or cliente_id in (select privado.mis_clientes()));
create policy "pedidos: crear" on public.pedidos for insert to authenticated
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "pedidos: editar" on public.pedidos for update to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "pedidos: borrar" on public.pedidos for delete to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()));

-- citas
drop policy "citas: el carpintero gestiona las suyas" on public.citas;
drop policy "citas: el cliente ve las suyas" on public.citas;
create policy "citas: ver" on public.citas for select to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()) or cliente_id in (select privado.mis_clientes()));
create policy "citas: crear" on public.citas for insert to authenticated
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "citas: editar" on public.citas for update to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "citas: borrar" on public.citas for delete to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()));

-- cotizaciones
drop policy "cotizaciones: el carpintero gestiona las suyas" on public.cotizaciones;
drop policy "cotizaciones: el cliente ve las enviadas" on public.cotizaciones;
create policy "cotizaciones: ver" on public.cotizaciones for select to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria())
         or (estado <> 'borrador' and privado.puede_ver_pedido(pedido_id)));
create policy "cotizaciones: crear" on public.cotizaciones for insert to authenticated
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "cotizaciones: editar" on public.cotizaciones for update to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()))
  with check (carpinteria_id = (select privado.mi_carpinteria()));
create policy "cotizaciones: borrar" on public.cotizaciones for delete to authenticated
  using (carpinteria_id = (select privado.mi_carpinteria()));

-- cotizacion_partidas
drop policy "partidas: el carpintero gestiona las suyas" on public.cotizacion_partidas;
drop policy "partidas: el cliente ve las de cotizaciones enviadas" on public.cotizacion_partidas;
create policy "partidas: ver" on public.cotizacion_partidas for select to authenticated
  using (exists (select 1 from public.cotizaciones q
                 where q.id = cotizacion_id
                   and (q.carpinteria_id = (select privado.mi_carpinteria())
                        or (q.estado <> 'borrador' and privado.puede_ver_pedido(q.pedido_id)))));
create policy "partidas: crear" on public.cotizacion_partidas for insert to authenticated
  with check (exists (select 1 from public.cotizaciones q
                      where q.id = cotizacion_id and q.carpinteria_id = (select privado.mi_carpinteria())));
create policy "partidas: editar" on public.cotizacion_partidas for update to authenticated
  using (exists (select 1 from public.cotizaciones q
                 where q.id = cotizacion_id and q.carpinteria_id = (select privado.mi_carpinteria())))
  with check (exists (select 1 from public.cotizaciones q
                      where q.id = cotizacion_id and q.carpinteria_id = (select privado.mi_carpinteria())));
create policy "partidas: borrar" on public.cotizacion_partidas for delete to authenticated
  using (exists (select 1 from public.cotizaciones q
                 where q.id = cotizacion_id and q.carpinteria_id = (select privado.mi_carpinteria())));
