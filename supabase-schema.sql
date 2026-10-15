-- SYLVA 7.0 : schéma de démarrage multi-entreprises
-- À exécuter uniquement dans un projet Supabase que vous contrôlez.
-- La création du premier admin global doit être faite manuellement depuis SQL Editor,
-- après que ce compte a été créé via Supabase Auth.
create extension if not exists pgcrypto;
create type public.sylva_role as enum ('worker','boss','admin');
create type public.sylva_site_status as enum ('planned','active','closed','invoiced','paid');
create table public.companies (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 2 and 150),
 active boolean not null default true, created_at timestamptz not null default now()
);
create table public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 company_id uuid references public.companies(id),
 role public.sylva_role not null default 'worker',
 first_name text not null default '', last_name text not null default '',
 active boolean not null default false, created_at timestamptz not null default now(),
 constraint admin_no_company check (role <> 'admin' or company_id is null),
 constraint workers_have_company check (role = 'admin' or company_id is not null)
);
create table public.machines (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 name text not null, model text, serial_number text, active boolean not null default true,
 created_at timestamptz not null default now(), unique(id,company_id)
);
create table public.sites (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 name text not null, client text, location text, latitude double precision, longitude double precision,
 start_date date, end_date date, status public.sylva_site_status not null default 'planned',
 notes text, updated_at timestamptz not null default now(), unique(id,company_id)
);
create table public.site_assignments (
 company_id uuid not null references public.companies(id), site_id uuid not null, user_id uuid not null references public.profiles(user_id),
 primary key(site_id,user_id), foreign key(site_id,company_id) references public.sites(id,company_id)
);
create table public.work_days (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 user_id uuid not null references public.profiles(user_id), site_id uuid, machine_id uuid,
 work_date date not null, start_time time not null, end_time time not null,
 break_start time not null, break_end time not null,
 worked_minutes integer not null check(worked_minutes between 0 and 1440),
 machine_meter numeric(12,2) check(machine_meter >= 0), observations text,
 updated_at timestamptz not null default now(), unique(company_id,user_id,work_date),
 foreign key(site_id,company_id) references public.sites(id,company_id),
 foreign key(machine_id,company_id) references public.machines(id,company_id)
);
create table public.piles (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 site_id uuid not null, created_by uuid references public.profiles(user_id),
 product text not null, label text, length_m numeric(12,3) not null check(length_m>0),
 width_m numeric(12,3) not null check(width_m>0), height_m numeric(12,3) not null check(height_m>0),
 unit text not null check(unit in ('st','m3','both')), notes text,
 created_at timestamptz not null default now(), foreign key(site_id,company_id) references public.sites(id,company_id)
);
create table public.maintenance (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 machine_id uuid not null, created_by uuid not null references public.profiles(user_id),
 performed_at date not null default current_date, meter numeric(12,2), description text not null,
 next_due_meter numeric(12,2), next_due_date date, created_at timestamptz not null default now(),
 foreign key(machine_id,company_id) references public.machines(id,company_id)
);
create table public.audit_log (
 id bigint generated always as identity primary key, company_id uuid references public.companies(id),
 actor_id uuid references public.profiles(user_id), action text not null,
 record_type text not null, record_id uuid, created_at timestamptz not null default now()
);
create index on public.work_days(company_id,work_date);
create index on public.sites(company_id,status);
create index on public.piles(site_id);
create index on public.maintenance(machine_id,performed_at);
-- Helpers security definer: rôle lu en base, jamais dans un champ client.
create function public.sylva_is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where user_id=auth.uid() and role='admin' and active)
$$;
create function public.sylva_is_boss(c uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where user_id=auth.uid() and company_id=c and role='boss' and active)
$$;
create function public.sylva_is_member(c uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where user_id=auth.uid() and company_id=c and active)
$$;
create function public.sylva_is_assigned(s uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.site_assignments where site_id=s and user_id=auth.uid())
$$;
create function public.sylva_site_editable(s uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.sites where id=s and status in ('planned','active'))
$$;
revoke all on function public.sylva_is_admin() from public;
revoke all on function public.sylva_is_boss(uuid) from public;
revoke all on function public.sylva_is_member(uuid) from public;
revoke all on function public.sylva_is_assigned(uuid) from public;
revoke all on function public.sylva_site_editable(uuid) from public;
grant execute on function public.sylva_is_admin() to authenticated;
grant execute on function public.sylva_is_boss(uuid) to authenticated;
grant execute on function public.sylva_is_member(uuid) to authenticated;
grant execute on function public.sylva_is_assigned(uuid) to authenticated;
grant execute on function public.sylva_site_editable(uuid) to authenticated;
-- Aucune écriture libre sur les profils : provisionnement via backend sécurisé.
alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.machines enable row level security;
alter table public.sites enable row level security;
alter table public.site_assignments enable row level security;
alter table public.work_days enable row level security;
alter table public.piles enable row level security;
alter table public.maintenance enable row level security;
alter table public.audit_log enable row level security;
create policy companies_read on public.companies for select to authenticated using (public.sylva_is_admin() or public.sylva_is_member(id));
create policy profiles_read on public.profiles for select to authenticated using (public.sylva_is_admin() or user_id=auth.uid() or public.sylva_is_boss(company_id));
create policy machines_read on public.machines for select to authenticated using (public.sylva_is_admin() or public.sylva_is_member(company_id));
create policy machines_write on public.machines for all to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id)) with check (public.sylva_is_admin() or public.sylva_is_boss(company_id));
create policy sites_read on public.sites for select to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (public.sylva_is_member(company_id) and public.sylva_is_assigned(id)));
create policy sites_write on public.sites for all to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id)) with check (public.sylva_is_admin() or public.sylva_is_boss(company_id));
create policy assignments_read on public.site_assignments for select to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id) or user_id=auth.uid());
create policy assignments_write on public.site_assignments for all to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id)) with check (public.sylva_is_admin() or public.sylva_is_boss(company_id));
create policy days_read on public.work_days for select to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (user_id=auth.uid() and public.sylva_is_member(company_id)));
create policy days_insert on public.work_days for insert to authenticated with check (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (user_id=auth.uid() and public.sylva_is_member(company_id) and date_trunc('month',work_date::timestamp)=date_trunc('month',current_date::timestamp) and (site_id is null or (public.sylva_site_editable(site_id) and public.sylva_is_assigned(site_id)))));
create policy days_update on public.work_days for update to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (user_id=auth.uid() and public.sylva_is_member(company_id) and date_trunc('month',work_date::timestamp)=date_trunc('month',current_date::timestamp))) with check (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (user_id=auth.uid() and public.sylva_is_member(company_id) and date_trunc('month',work_date::timestamp)=date_trunc('month',current_date::timestamp) and (site_id is null or (public.sylva_site_editable(site_id) and public.sylva_is_assigned(site_id)))));
create policy days_delete on public.work_days for delete to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (user_id=auth.uid() and public.sylva_is_member(company_id) and date_trunc('month',work_date::timestamp)=date_trunc('month',current_date::timestamp)));
create policy piles_read on public.piles for select to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (public.sylva_is_member(company_id) and public.sylva_is_assigned(site_id)));
create policy piles_insert on public.piles for insert to authenticated with check (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (created_by=auth.uid() and public.sylva_is_member(company_id) and public.sylva_is_assigned(site_id) and public.sylva_site_editable(site_id)));
create policy piles_update on public.piles for update to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (created_by=auth.uid() and public.sylva_is_member(company_id) and public.sylva_is_assigned(site_id) and public.sylva_site_editable(site_id))) with check (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (created_by=auth.uid() and public.sylva_is_member(company_id) and public.sylva_is_assigned(site_id) and public.sylva_site_editable(site_id)));
create policy maintenance_read on public.maintenance for select to authenticated using (public.sylva_is_admin() or public.sylva_is_member(company_id));
create policy maintenance_insert on public.maintenance for insert to authenticated with check (public.sylva_is_admin() or public.sylva_is_boss(company_id) or (created_by=auth.uid() and public.sylva_is_member(company_id)));
create policy audit_read on public.audit_log for select to authenticated using (public.sylva_is_admin() or public.sylva_is_boss(company_id));
-- Les tables companies, profiles et audit_log sont écrites uniquement par un backend de confiance.
-- Ne jamais placer la clé service_role dans le navigateur ou le dépôt GitHub.
-- À compléter avant mise en production : audit triggers, invitations, gestion des
-- changements de rôle, restrictions de transition des statuts, contrôle des
-- références inter-entreprises sur user_id, quotas photos, sauvegardes et tests RLS.
