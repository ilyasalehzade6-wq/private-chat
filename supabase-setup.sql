create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  display_name text,
  avatar_url text,
  is_online boolean default false,
  last_seen timestamp with time zone default timezone('utc'::text, now()),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists public.conversations (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  user1_id uuid references auth.users on delete cascade not null,
  user2_id uuid references auth.users on delete cascade not null,
  last_message text,
  last_message_at timestamp with time zone,
  constraint users_different check (user1_id <> user2_id),
  constraint unique_pair unique (user1_id, user2_id)
);

create table if not exists public.messages (
  id uuid default gen_random_uuid() primary key,
  conversation_id uuid references public.conversations on delete cascade not null,
  sender_id uuid references auth.users on delete cascade not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  read_at timestamp with time zone,
  constraint content_not_empty check (char_length(content) > 0 and char_length(content) <= 5000)
);

create index if not exists idx_messages_conversation on public.messages(conversation_id, created_at);
create index if not exists idx_conversations_users on public.conversations(user1_id, user2_id);
create index if not exists idx_profiles_username on public.profiles(username);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data->>'display_name', new.email)
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.update_conversation_last_message()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  update public.conversations
  set last_message = new.content, last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists on_message_created on public.messages;
create trigger on_message_created
  after insert on public.messages
  for each row execute function public.update_conversation_last_message();

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists "profiles_select_all" on public.profiles;
create policy "profiles_select_all" on public.profiles for select using (auth.role() = 'authenticated');

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "conversations_select_mine" on public.conversations;
create policy "conversations_select_mine" on public.conversations for select using (auth.uid() = user1_id or auth.uid() = user2_id);

drop policy if exists "conversations_insert_mine" on public.conversations;
create policy "conversations_insert_mine" on public.conversations for insert with check (auth.uid() = user1_id or auth.uid() = user2_id);

drop policy if exists "conversations_update_mine" on public.conversations;
create policy "conversations_update_mine" on public.conversations for update using (auth.uid() = user1_id or auth.uid() = user2_id);

drop policy if exists "messages_select_mine" on public.messages;
create policy "messages_select_mine" on public.messages for select using (
  exists (select 1 from public.conversations c
    where c.id = messages.conversation_id
      and (c.user1_id = auth.uid() or c.user2_id = auth.uid()))
);

drop policy if exists "messages_insert_mine" on public.messages;
create policy "messages_insert_mine" on public.messages for insert with check (
  auth.uid() = sender_id
  and exists (select 1 from public.conversations c
    where c.id = conversation_id
      and (c.user1_id = auth.uid() or c.user2_id = auth.uid()))
);

drop policy if exists "messages_update_read" on public.messages;
create policy "messages_update_read" on public.messages for update using (
  exists (select 1 from public.conversations c
    where c.id = messages.conversation_id
      and (c.user1_id = auth.uid() or c.user2_id = auth.uid()))
);

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.profiles;
