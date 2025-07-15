-- DROP SCHEMA public CASCADE;
-- CREATE SCHEMA public;
CREATE EXTENSION IF NOT EXISTS ltree;

CREATE OR REPLACE FUNCTION
  uuid_generate_v7()
RETURNS
  uuid
LANGUAGE
  plpgsql
PARALLEL SAFE
AS $$
  DECLARE
    -- The current UNIX timestamp in milliseconds
    unix_time_ms CONSTANT bytea NOT NULL DEFAULT substring(int8send((extract(epoch FROM clock_timestamp()) * 1000)::bigint) from 3);

    -- The buffer used to create the UUID, starting with the UNIX timestamp and followed by random bytes
    buffer                bytea NOT NULL DEFAULT unix_time_ms || gen_random_bytes(10);
  BEGIN
    -- Set most significant 4 bits of 7th byte to 7 (for UUID v7), keeping the last 4 bits unchanged
    buffer = set_byte(buffer, 6, (b'0111' || get_byte(buffer, 6)::bit(4))::bit(8)::int);

    -- Set most significant 2 bits of 9th byte to 2 (the UUID variant specified in RFC 4122), keeping the last 6 bits unchanged
    buffer = set_byte(buffer, 8, (b'10'   || get_byte(buffer, 8)::bit(6))::bit(8)::int);

    RETURN encode(buffer, 'hex');
  END
$$
;

SELECT pg_size_pretty(pg_total_relation_size('"public"."chat_message"'));

CREATE OR REPLACE FUNCTION update_full_tag()
RETURNS TRIGGER AS $$
BEGIN
    NEW.full_tag = (
        SELECT CONCAT(tag_category.name, '_', NEW.name)
        FROM tag_category
        WHERE tag_category.id = NEW.category_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_full_tag
BEFORE INSERT OR UPDATE ON tag
FOR EACH ROW
EXECUTE FUNCTION update_full_tag();


SELECT con.*
    FROM pg_catalog.pg_constraint con
        INNER JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid
        INNER JOIN pg_catalog.pg_namespace nsp ON nsp.oid = connamespace
        WHERE nsp.nspname = 'public'
             AND rel.relname = 'chat_message';

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS server_build_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  server_id UUID NOT NULL,
  message TEXT,
  building JSON,
  player JSON,
  created_at TIMESTAMPTZ
)


CREATE TABLE IF NOT EXISTS mods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name TEXT UNIQUE NOT NULL,
  position SMALLINT DEFAULT 0,
  created_at TIMESTAMPTZ
);


CREATE TABLE IF NOT EXISTS server_admin (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  server_id UUID NOT NULL,
  user_id UUID NOT NULL,
  created_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS server_env (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  server_id UUID NOT NULL,
  name TEXT NOT NULL,
  value TEXT NOT NULL,
  created_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS server_manager (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  address TEXT,
  name text,
  user_id UUID NOT NULL,
  status TEXT default 'DOWN',
  security_key TEXT NOT NULL,
  access_token TEXT NOT NULL,
  created_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS servers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name TEXT NOT NULL,
  description TEXT,
  mode TEXT NOT NULL,
  gamemode TEXT,
  port INT NOT NULL,
  host_command TEXT,
  status TEXT,
  webhook TEXT,
  discord_channel_id TEXT,
  avatar TEXT,
  players INT DEFAULT 0,
  is_default boolean default FALSE,
  is_official boolean default FALSE,
  is_auto_turn_off boolean default TRUE,
  is_hub boolean default FALSE,
  manager_id UUID 
)

CREATE TABLE IF NOT EXISTS api_config (
  id SERIAL PRIMARY KEY,
  version INTEGER DEFAULT 1,
  log_channel_id TEXT,
  main_guild_id TEXT,
  server_category_channel_id TEXT,
  translation_prompt TEXT,
  information_prompt TEXT,
  mindustry_gpt_prompt TEXT
);

CREATE TABLE IF NOT EXISTS user_session (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  session_id TEXT,
  user_id UUID
);

CREATE TABLE IF NOT EXISTS download_count (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  ip TEXT,
  item_id UUID
);

CREATE TABLE IF NOT EXISTS translations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
    key_id UUID,
    language text NOT NULL,
    value TEXT NOT NULL,
    fulltext TSVECTOR,
    is_translated boolean default false
);

CREATE TABLE IF NOT EXISTS translation_key (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
    key_group text NOT NULL,
    key TEXT NOT NULL
);

CREATE OR REPLACE FUNCTION update_translation_fulltext()
RETURNS trigger AS $$
DECLARE
    key_record RECORD;
BEGIN
    -- Fetch the key and key_group from the translation_key table
    SELECT key, key_group
    INTO key_record
    FROM translation_key
    WHERE id = NEW.key_id;

    -- Update the fulltext field
    NEW.fulltext := to_tsvector(
        'english',
        REPLACE(COALESCE(key_record.key, ''), '-', ' ') || ' ' ||
        REPLACE(COALESCE(key_record.key_group, ''), '-', ' ') || ' ' ||
        REPLACE(COALESCE(NEW.value, ''), '-', ' ')
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_update_translation_fulltext
BEFORE INSERT OR UPDATE ON translations
FOR EACH ROW
EXECUTE FUNCTION update_translation_fulltext();



CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name TEXT NOT NULL,
  about TEXT,
  image_url text,
  thumbnail text,
  stats json,
  updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS mindustry_player (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  uuid TEXT NOT NULL,
  ip TEXT NOT NULL,
  name TEXT NOT NULL,
  user_id UUID NOT NULL,
  stats json,
  created_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS password_account (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  email TEXT NOT NULL,
  password TEXT NOT NULL,
  user_id UUID NOT NULL,
  updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS social_provider_account (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  user_id UUID NOT NULL,
  provider TEXT NOT NULL,
  provider_id TEXT NOT NULL,
  updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS roles (
  id SERIAL PRIMARY KEY,
  position SMALLINT,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  icon TEXT,
  color TEXT
);


CREATE TABLE IF NOT EXISTS user_role (
  user_id UUID NOT NULL,
  role_id SERIAL NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (user_id, role_id)
);


CREATE TABLE IF NOT EXISTS authority (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL,
  authority_group TEXT NOT NULL,
  updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS user_authority (
  user_id UUID NOT NULL,
  authority_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (user_id, authority_id)
);


CREATE TABLE IF NOT EXISTS role_authority (
  role_id SERIAL NOT NULL,
  authority_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (role_id, authority_id)
);


CREATE TABLE IF NOT EXISTS tag (
id SERIAL PRIMARY KEY,
name TEXT NOT NULL,
full_tag TEXT NOT NULL,
position SMALLINT,
category_id SERIAL NOT NULL,
mod_id UUID,
icon TEXT,
description TEXT NOT NULL
);


CREATE TABLE IF NOT EXISTS tag_category (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  color TEXT NOT NULL,
  duplicate BOOL  
);


CREATE TABLE IF NOT EXISTS tag_group (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT
);


CREATE TABLE IF NOT EXISTS tag_group_info_tag (
  id SERIAL PRIMARY KEY,
  group_id SERIAL NOT NULL,
  category_id SERIAL NOT NULL,
  position SMALLINT DEFAULT 0,
  PRIMARY KEY (group_id, category_id)
);


CREATE TABLE IF NOT EXISTS item (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  is_verified BOOL DEFAULT FALSE,
  verifier_id UUID,
  likes INTEGER DEFAULT 0,
  dislikes INTEGER DEFAULT 0,
  item_type SMALLINT NOT NULL,
  user_id UUID NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  fulltext TSVECTOR
);

CREATE TABLE IF NOT EXISTS schematic (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  item_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  metadata JSON,
  meta JSONB,
  fulltext TSVECTOR,
  slug TEXT NOT NULL,
  data BYTEA NOT NULL,
  width SMALLINT,
  height SMALLINT,
  is_curated BOOL DEFAULT FALSE,
  hidden BOOL DEFAULT FALSE
);


CREATE TABLE IF NOT EXISTS map (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  item_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  fulltext TSVECTOR,
  slug TEXT NOT NULL,
  meta JSONB,
  data BYTEA NOT NULL,
  width SMALLINT,
  height SMALLINT,
  is_curated BOOL DEFAULT FALSE,
  is_private boolean DEFAULT false,
  hidden BOOL DEFAULT FALSE
);


CREATE TABLE IF NOT EXISTS post (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  update_for_id UUID,
  item_id UUID NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  slug TEXT NOT NULL,
  is_curated BOOL DEFAULT FALSE,
  hidden BOOL DEFAULT FALSE,
  image_urls text[],
  lang text
);


CREATE TABLE IF NOT EXISTS plugin (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),    
  item_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  url TEXT NOT NULL,
  is_private boolean DEFAULT false,
  is_default boolean DEFAULT false,
  bearer_token TEXT,
  last_release_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS item_tag (
  item_id UUID NOT NULL,
  tag_id SERIAL NOT NULL,
  PRIMARY KEY (item_id, tag_id)
);


CREATE TABLE IF NOT EXISTS item_like (
  item_id UUID NOT NULL,
  user_id UUID NOT NULL,
  state SMALLINT,
  PRIMARY KEY (item_id, user_id)
);



CREATE TABLE IF NOT EXISTS server (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  address TEXT NOT NULL,
  name TEXT,
  description TEXT,
  map_name TEXT,
  wave INTEGER DEFAULT -1,
  player INTEGER DEFAULT 0,
  planId INTEGER DEFAULT 0,
  player_limit INTEGER,
  version INTEGER,
  version_type TEXT,
  mode TEXT,
  mode_name TEXT,
  image TEXT,
  is_default boolean DEFAULT false,
  likes INTEGER DEFAULT 0,
  ping INTEGER DEFAULT -1,
  port INTEGER DEFAULT 6567,
  last_online_time TIMESTAMPTZ,
  is_online BOOL
);


CREATE TABLE IF NOT EXISTS server
 (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  user_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  mode TEXT DEFAULT 'survival',
  port INTEGER,
  is_official BOOLEAN,
  start_command TEXT
);

CREATE TABLE IF NOT EXISTS server_login_log
(
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  server_id UUID NOT NULL,
  name TEXT NOT NULL,
  uuid TEXT NOT NULL,
  ip TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  environment SMALLINT,
  user_id UUID,
  ip TEXT,
  request_url TEXT,
  content TEXT,
  type SMALLINT,
  created_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS chat_room (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name TEXT NOT NULL,
  is_public BOOL DEFAULT FALSE,
  created_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS chat_message (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  room_id UUID NOT NULL,
  user_id UUID NOT NULL,
  content TEXT,
  context_type TEXT default 'TEXT',
  attachments TEXT[],
  created_at TIMESTAMPTZ
);


CREATE TABLE IF NOT EXISTS metric (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  value BIGINT,
  type SMALLINT,
  metric_key text,
  created_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS notification (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  user_id UUID NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  read BOOL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL
);


CREATE TABLE IF NOT EXISTS user_login_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  user_id UUID,
  ip TEXT NOT NULL,
  os TEXT,
  browser TEXT,
  counts SMALLINT DEFAULT 0,
  client SMALLINT,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS error_report (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
    content json,
    status TEXT DEFAULT 'PENDING',
    ip TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS error_report_status_index ON error_report (status);
CREATE INDEX IF NOT EXISTS error_report_created_at_index ON error_report (created_at);
CREATE INDEX IF NOT EXISTS error_report_ip_index ON error_report (ip);


CREATE TABLE IF NOT EXISTS comment (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  reply_to UUID,
  item_id UUID NOT NULL,
  user_id UUID NOT NULL,
  path LTREE NOT NULL,
  attachments TEXT[],
  level SMALLINT NOT NULL DEFAULT 0,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS document_tree (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  path LTREE NOT NULL,
  index SMALLINT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS document (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  item_id UUID NOT NULL,
  tree_id UUID NOT NULL,
  user_id UUID NOT NULL,
  title TEXT,
  content TEXT,
  language TEXT NOT NULL,
  updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS schematic_item_id ON schematic (item_id);
CREATE INDEX IF NOT EXISTS map_item_id ON map (item_id);
CREATE INDEX IF NOT EXISTS post_item_id ON post (item_id);

CREATE INDEX IF NOT EXISTS item_created_at_index ON item (created_at);

CREATE INDEX IF NOT EXISTS item_updated_at_index ON item (updated_at);

CREATE INDEX IF NOT EXISTS comment_index ON comment (item_id);
CREATE INDEX IF NOT EXISTS comment_path_index ON comment (path);

CREATE UNIQUE INDEX IF NOT EXISTS schematic_data_index ON schematic  USING hash (data);

CREATE UNIQUE INDEX IF NOT EXISTS map_data_index ON map USING hash (data);

CREATE UNIQUE INDEX IF NOT EXISTS password_account_email_index ON password_account (email);
CREATE UNIQUE INDEX IF NOT EXISTS password_account_user_id_index ON password_account (user_id);

CREATE UNIQUE INDEX IF NOT EXISTS social_provider_and_provider_id_index ON social_provider_account (provider, provider_id);

CREATE UNIQUE INDEX IF NOT EXISTS download_count_index ON download_count (item_id, ip);

CREATE INDEX IF NOT EXISTS social_provider_user_id_index ON social_provider_account (user_id);
CREATE INDEX IF NOT EXISTS social_provider_index ON social_provider_account (provider);

CREATE UNIQUE INDEX IF NOT EXISTS role_name_index ON roles (name);

CREATE INDEX IF NOT EXISTS user_role_user_id_index ON user_role (user_id);
CREATE INDEX IF NOT EXISTS user_role_role_id_index ON user_role (role_id);

CREATE INDEX IF NOT EXISTS authority_name_index ON authority (name);

CREATE INDEX IF NOT EXISTS user_authority_user_id_index ON user_authority (user_id);
CREATE INDEX IF NOT EXISTS user_authority_authority_id_index ON user_authority (authority_id);

CREATE INDEX IF NOT EXISTS role_authority_role_id_index ON role_authority (role_id);
CREATE INDEX IF NOT EXISTS role_authority_authority_id_index ON role_authority (authority_id);

CREATE INDEX IF NOT EXISTS item_tag_item_id_index ON item_tag (item_id);
CREATE INDEX IF NOT EXISTS item_tag_tag_id_index ON item_tag (tag_id);

CREATE INDEX idx_item_tag_item_id_tag_id ON item_tag (item_id, tag_id);

CREATE INDEX IF NOT EXISTS item_like_item_id_index ON item_like (item_id);
CREATE INDEX IF NOT EXISTS item_like_user_id_index ON item_like (user_id);


CREATE INDEX IF NOT EXISTS server_login_server_id_index ON servers (id);

CREATE INDEX IF NOT EXISTS log_type_env_index ON logs ("type", environment);
CREATE INDEX IF NOT EXISTS log_type_index ON logs ("type");
CREATE INDEX IF NOT EXISTS log_user_id_index ON logs (user_id);
CREATE INDEX IF NOT EXISTS log_ip_index ON logs (ip);
CREATE INDEX IF NOT EXISTS log_created_at_index ON logs (created_at);

CREATE INDEX IF NOT EXISTS chat_message_user_id_index ON chat_message (user_id);
CREATE INDEX IF NOT EXISTS chat_message_room_index ON chat_message (room_id);
CREATE INDEX IF NOT EXISTS chat_message_created_at_index ON chat_message (created_at);

CREATE INDEX IF NOT EXISTS chat_message_room_name_index ON chat_room (name);

CREATE INDEX IF NOT EXISTS category_mod_id_index ON tag (category_id,mod_id);
CREATE UNIQUE INDEX IF NOT EXISTS category_name_index ON tag (name, category_id);

CREATE UNIQUE INDEX IF NOT EXISTS chat_room_name ON chat_room (name);

CREATE UNIQUE INDEX IF NOT EXISTS user_login_history_search_index ON user_login_history (ip, created_at, client);

CREATE UNIQUE INDEX IF NOT EXISTS translation_key_key_id_index ON translations (key_id, language);

CREATE UNIQUE INDEX IF NOT EXISTS translation_key_search_index ON translation_key (key_group, key);

CREATE UNIQUE INDEX IF NOT EXISTS translation_search_index ON translations (key_group, key);
CREATE INDEX IF NOT EXISTS translation_is_translated_index ON translations (is_translated);
CREATE INDEX IF NOT EXISTS translation_language_index ON translations (language);

CREATE INDEX IF NOT EXISTS mindustry_player_user_id_index ON mindustry_player (user_id) 

CREATE INDEX IF NOT EXISTS server_admin_user_id_index ON server_admin (user_id) 
CREATE INDEX IF NOT EXISTS server_admin_server_id_index ON server_admin (server_id)

CREATE INDEX IF NOT EXISTS server_env_server_id_index ON server_env (server_id)

CREATE INDEX IF NOT EXISTS server_build_log_server_id_index ON server_build_log (server_id, id)

CREATE INDEX IF NOT EXISTS metric_index ON metric (type, created_at) 

CREATE index schematic_fulltext_search_idx
ON "schematic" USING gin
(fulltext);

UPDATE schematic set fulltext = to_tsvector(name || ' ' || description);

ALTER TABLE "server_login_log" add foreign key ("server_id") references "servers" ("id") on delete cascade;
ALTER TABLE "comment" add foreign key ("item_id") references "item" ("id") on delete cascade;

ALTER TABLE "user_session" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "password_account" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "social_provider_account" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "user_role" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "user_role" add foreign key ("role_id") references "roles" ("id") on delete cascade;

ALTER TABLE "user_authority" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "user_authority" add foreign key ("authority_id") references "authority" ("id") on delete cascade;

ALTER TABLE "role_authority" add foreign key ("role_id") references "roles" ("id") on delete cascade;

ALTER TABLE "role_authority" add foreign key ("authority_id") references "authority" ("id") on delete cascade;

ALTER TABLE "tag" add foreign key ("category_id") references "tag_category" ("id") on delete cascade;

ALTER TABLE "tag_group_info_tag" add foreign key ("group_id") references "tag_group" ("id") on delete cascade;

ALTER TABLE "tag_group_info_tag" add foreign key ("category_id") references "tag_category" ("id") on delete cascade;

ALTER TABLE "item" add foreign key ("verifier_id") references "users" ("id") on delete cascade;

ALTER TABLE "item_tag" add foreign key ("item_id") references "item" ("id") on delete cascade;

ALTER TABLE "item_tag" add foreign key ("tag_id") references "tag" ("id") on delete cascade;

ALTER TABLE "item_like" add foreign key ("item_id") references "item" ("id") on delete cascade;

ALTER TABLE "item_like" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "post" add foreign key ("update_for_id") references "post" ("id") on delete cascade;

ALTER TABLE "post" add foreign key ("item_id") references "item" ("id") on delete cascade;

ALTER TABLE "map" add foreign key ("update_for_id") references "map" ("id") on delete cascade;

ALTER TABLE "map" add foreign key ("item_id") references "item" ("id") on delete cascade;

ALTER TABLE "schematic" add foreign key ("update_for_id") references "schematic" ("id") on delete cascade;

ALTER TABLE "schematic" add foreign key ("item_id") references "item" ("id") on delete cascade;

ALTER TABLE "plugin" add foreign key ("item_id") references "item" ("id") on delete cascade;

ALTER TABLE "server" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "chat_message" add foreign key ("room_id") references "chat_room" ("id") on delete cascade;

ALTER TABLE "chat_message" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "notification" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "user_login_history" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "mindustry_player" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "server_env" add foreign key ("server_id") references "servers" ("id") on delete cascade;

ALTER TABLE "server_admin" add foreign key ("server_id") references "servers" ("id") on delete cascade;
ALTER TABLE "server_admin" add foreign key ("user_id") references "users" ("id") on delete cascade;

ALTER TABLE "server_build_log" add foreign key ("server_id") references "server" ("id") on delete cascade;

ALTER TABLE "tag" add foreign key ("mod_id") references "mods" ("id") on delete cascade;

ALTER TABLE "translations" add foreign key ("key_id") references "translation_key" ("id") on delete cascade;

