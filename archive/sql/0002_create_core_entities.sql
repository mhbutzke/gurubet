-- Core geographical reference entities from Sportmonks Core API
create table if not exists public.continents (
  id bigint primary key,
  name text not null,
  code text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create table if not exists public.countries (
  id bigint primary key,
  continent_id bigint references public.continents(id),
  name text not null,
  official_name text,
  fifa_name text,
  iso2 text,
  iso3 text,
  latitude double precision,
  longitude double precision,
  borders text[],
  image_path text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists countries_iso2_idx on public.countries (iso2);
create index if not exists countries_continent_idx on public.countries (continent_id);

create table if not exists public.regions (
  id bigint primary key,
  country_id bigint references public.countries(id),
  name text not null,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists regions_country_idx on public.regions (country_id);

create table if not exists public.cities (
  id bigint primary key,
  country_id bigint references public.countries(id),
  region_id bigint references public.regions(id),
  name text not null,
  latitude double precision,
  longitude double precision,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists cities_country_idx on public.cities (country_id);
create index if not exists cities_region_idx on public.cities (region_id);

create table if not exists public.core_types (
  id bigint primary key,
  name text not null,
  code text,
  developer_name text,
  model_type text,
  stat_group text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);
