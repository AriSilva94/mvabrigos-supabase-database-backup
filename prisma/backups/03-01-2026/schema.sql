


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."dynamic_kind" AS ENUM (
    'abrigo',
    'lar'
);


ALTER TYPE "public"."dynamic_kind" OWNER TO "postgres";


CREATE TYPE "public"."shelter_volunteer_status" AS ENUM (
    'pending',
    'approved',
    'rejected'
);


ALTER TYPE "public"."shelter_volunteer_status" OWNER TO "postgres";


CREATE TYPE "public"."user_origin" AS ENUM (
    'wordpress_migrated',
    'supabase_native',
    'admin_created'
);


ALTER TYPE "public"."user_origin" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'admin',
    'abrigo',
    'voluntario'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_shelter_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_changed_fields TEXT[] := ARRAY[]::TEXT[];
  v_operation TEXT;
  v_old_data JSONB;
  v_new_data JSONB;
  v_changed_by uuid;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    v_operation := 'DELETE';
    v_old_data := row_to_json(OLD)::JSONB;
    v_new_data := NULL;
  ELSIF (TG_OP = 'INSERT') THEN
    v_operation := 'INSERT';
    v_old_data := NULL;
    v_new_data := row_to_json(NEW)::JSONB;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF (OLD.active IS DISTINCT FROM NEW.active) AND (OLD.name = NEW.name) AND (OLD.cnpj = NEW.cnpj) THEN
      v_operation := 'STATUS_CHANGE';
    ELSE
      v_operation := 'UPDATE';
    END IF;
    v_old_data := row_to_json(OLD)::JSONB;
    v_new_data := row_to_json(NEW)::JSONB;

    IF OLD.shelter_type IS DISTINCT FROM NEW.shelter_type THEN v_changed_fields := array_append(v_changed_fields, 'shelter_type'); END IF;
    IF OLD.cnpj IS DISTINCT FROM NEW.cnpj THEN v_changed_fields := array_append(v_changed_fields, 'cnpj'); END IF;
    IF OLD.name IS DISTINCT FROM NEW.name THEN v_changed_fields := array_append(v_changed_fields, 'name'); END IF;
    IF OLD.cep IS DISTINCT FROM NEW.cep THEN v_changed_fields := array_append(v_changed_fields, 'cep'); END IF;
    IF OLD.street IS DISTINCT FROM NEW.street THEN v_changed_fields := array_append(v_changed_fields, 'street'); END IF;
    IF OLD.number IS DISTINCT FROM NEW.number THEN v_changed_fields := array_append(v_changed_fields, 'number'); END IF;
    IF OLD.district IS DISTINCT FROM NEW.district THEN v_changed_fields := array_append(v_changed_fields, 'district'); END IF;
    IF OLD.state IS DISTINCT FROM NEW.state THEN v_changed_fields := array_append(v_changed_fields, 'state'); END IF;
    IF OLD.city IS DISTINCT FROM NEW.city THEN v_changed_fields := array_append(v_changed_fields, 'city'); END IF;
    IF OLD.website IS DISTINCT FROM NEW.website THEN v_changed_fields := array_append(v_changed_fields, 'website'); END IF;
    IF OLD.foundation_date IS DISTINCT FROM NEW.foundation_date THEN v_changed_fields := array_append(v_changed_fields, 'foundation_date'); END IF;
    IF OLD.species IS DISTINCT FROM NEW.species THEN v_changed_fields := array_append(v_changed_fields, 'species'); END IF;
    IF OLD.additional_species IS DISTINCT FROM NEW.additional_species THEN v_changed_fields := array_append(v_changed_fields, 'additional_species'); END IF;
    IF OLD.temporary_agreement IS DISTINCT FROM NEW.temporary_agreement THEN v_changed_fields := array_append(v_changed_fields, 'temporary_agreement'); END IF;
    IF OLD.initial_dogs IS DISTINCT FROM NEW.initial_dogs THEN v_changed_fields := array_append(v_changed_fields, 'initial_dogs'); END IF;
    IF OLD.initial_cats IS DISTINCT FROM NEW.initial_cats THEN v_changed_fields := array_append(v_changed_fields, 'initial_cats'); END IF;
    IF OLD.authorized_name IS DISTINCT FROM NEW.authorized_name THEN v_changed_fields := array_append(v_changed_fields, 'authorized_name'); END IF;
    IF OLD.authorized_role IS DISTINCT FROM NEW.authorized_role THEN v_changed_fields := array_append(v_changed_fields, 'authorized_role'); END IF;
    IF OLD.authorized_email IS DISTINCT FROM NEW.authorized_email THEN v_changed_fields := array_append(v_changed_fields, 'authorized_email'); END IF;
    IF OLD.authorized_phone IS DISTINCT FROM NEW.authorized_phone THEN v_changed_fields := array_append(v_changed_fields, 'authorized_phone'); END IF;
    IF OLD.active IS DISTINCT FROM NEW.active THEN v_changed_fields := array_append(v_changed_fields, 'active'); END IF;
  END IF;

  v_changed_by := auth.uid();
  IF v_changed_by IS NULL THEN
    v_changed_by := COALESCE(NEW.profile_id, OLD.profile_id);
  END IF;

  INSERT INTO public.shelter_history (
    shelter_id,
    profile_id,
    operation,
    old_data,
    new_data,
    changed_fields,
    changed_at,
    changed_by
  ) VALUES (
    COALESCE(NEW.id, OLD.id),
    COALESCE(NEW.profile_id, OLD.profile_id),
    v_operation,
    v_old_data,
    v_new_data,
    v_changed_fields,
    now(),
    v_changed_by
  );

  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


ALTER FUNCTION "public"."log_shelter_changes"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."log_shelter_changes"() IS 'Registra automaticamente alterações na tabela shelters';



CREATE OR REPLACE FUNCTION "public"."set_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_vacancy_applications_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_vacancy_applications_updated_at"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text",
    "phone" "text",
    "role" "public"."user_role",
    "wp_user_id" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "origin" "public"."user_origin" DEFAULT 'supabase_native'::"public"."user_origin" NOT NULL,
    "is_team_only" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shelter_dynamics" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "shelter_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "reference_date" "date",
    "reference_period" "text",
    "dynamic_type" "text" DEFAULT 'dinamica'::"text" NOT NULL,
    "entradas_de_animais" integer DEFAULT 0,
    "entradas_de_gatos" integer DEFAULT 0,
    "adocoes_caes" integer DEFAULT 0,
    "adocoes_gatos" integer DEFAULT 0,
    "devolucoes_caes" integer DEFAULT 0,
    "devolucoes_gatos" integer DEFAULT 0,
    "eutanasias_caes" integer DEFAULT 0,
    "eutanasias_gatos" integer DEFAULT 0,
    "mortes_naturais_caes" integer DEFAULT 0,
    "mortes_naturais_gatos" integer DEFAULT 0,
    "doencas_caes" integer DEFAULT 0,
    "doencas_gatos" integer DEFAULT 0,
    "retorno_de_caes" integer DEFAULT 0,
    "retorno_de_gatos" integer DEFAULT 0,
    "retorno_local_caes" integer DEFAULT 0,
    "retorno_local_gatos" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shelter_dynamics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shelter_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "shelter_id" "uuid" NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "operation" "text" NOT NULL,
    "old_data" "jsonb",
    "new_data" "jsonb",
    "changed_fields" "text"[],
    "changed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "changed_by" "uuid",
    CONSTRAINT "shelter_history_operation_check" CHECK (("operation" = ANY (ARRAY[('INSERT'::character varying)::"text", ('UPDATE'::character varying)::"text", ('DELETE'::character varying)::"text", ('STATUS_CHANGE'::character varying)::"text"]))),
    CONSTRAINT "shelter_history_shelter_id_idx" CHECK (("shelter_id" IS NOT NULL))
);


ALTER TABLE "public"."shelter_history" OWNER TO "postgres";


COMMENT ON TABLE "public"."shelter_history" IS 'Histórico de alterações dos cadastros de abrigos';



COMMENT ON COLUMN "public"."shelter_history"."operation" IS 'Tipo de operação: INSERT, UPDATE, DELETE, STATUS_CHANGE';



COMMENT ON COLUMN "public"."shelter_history"."old_data" IS 'Dados antes da alteração (JSON)';



COMMENT ON COLUMN "public"."shelter_history"."new_data" IS 'Dados após a alteração (JSON)';



COMMENT ON COLUMN "public"."shelter_history"."changed_fields" IS 'Lista de campos que foram alterados';



CREATE TABLE IF NOT EXISTS "public"."shelter_volunteers" (
    "shelter_id" "uuid" NOT NULL,
    "volunteer_id" "uuid" NOT NULL,
    "role" "text",
    "status" "public"."shelter_volunteer_status" DEFAULT 'pending'::"public"."shelter_volunteer_status",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shelter_volunteers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shelters" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wp_post_id" integer,
    "profile_id" "uuid",
    "name" "text" NOT NULL,
    "authorized_name" "text",
    "authorized_role" "text",
    "shelter_type" "text",
    "temporary_agreement" "text",
    "cnpj" "text",
    "authorized_email" "text",
    "authorized_phone" "text",
    "website" "text",
    "street" "text",
    "number" integer,
    "district" "text",
    "city" "text",
    "state" "text",
    "cep" "text",
    "species" "text",
    "additional_species" "jsonb" DEFAULT '[]'::"jsonb",
    "foundation_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "initial_dogs" integer,
    "initial_cats" integer,
    "accept_terms" boolean DEFAULT false NOT NULL,
    "cpf" "text",
    "wp_post_author" integer
);


ALTER TABLE "public"."shelters" OWNER TO "postgres";


COMMENT ON COLUMN "public"."shelters"."active" IS 'Indica se o abrigo está ativo no sistema. Inativos não aparecem em buscas públicas.';



COMMENT ON COLUMN "public"."shelters"."wp_post_author" IS 'ID do usuário WordPress (post_author) que criou o abrigo - usado para vincular ao profile do dono';



CREATE TABLE IF NOT EXISTS "public"."team_memberships" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_profile_id" "uuid",
    "owner_wp_user_id" bigint,
    "member_profile_id" "uuid",
    "member_wp_user_id" bigint,
    "member_email" "text",
    "abrigo_post_id" bigint,
    "status" "text" DEFAULT 'pending_member'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "team_memberships_status_check" CHECK (("status" = ANY (ARRAY['pending_owner'::"text", 'pending_member'::"text", 'active'::"text"])))
);


ALTER TABLE "public"."team_memberships" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vacancies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wp_post_id" integer,
    "shelter_id" "uuid",
    "shelter_name_raw" "text",
    "title" "text" NOT NULL,
    "description" "text",
    "cidade" "text",
    "estado" "text",
    "area_atuacao" "text",
    "carga_horaria" "text",
    "periodo" "text",
    "habilidades_e_funcoes" "text",
    "perfil_dos_voluntarios" "text",
    "tipo_demanda" "text",
    "inscritos" integer,
    "status" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "slug" "text",
    "quantidade" "text",
    "is_published" boolean DEFAULT true
);


ALTER TABLE "public"."vacancies" OWNER TO "postgres";


COMMENT ON COLUMN "public"."vacancies"."slug" IS 'URL-friendly identifier for vacancy';



CREATE TABLE IF NOT EXISTS "public"."vacancy_applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vacancy_id" "uuid" NOT NULL,
    "volunteer_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "applied_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."vacancy_applications" OWNER TO "postgres";


COMMENT ON TABLE "public"."vacancy_applications" IS 'Candidaturas de voluntários em vagas de voluntariado';



COMMENT ON COLUMN "public"."vacancy_applications"."id" IS 'Identificador único da candidatura';



COMMENT ON COLUMN "public"."vacancy_applications"."vacancy_id" IS 'Referência à vaga (FK → vacancies.id)';



COMMENT ON COLUMN "public"."vacancy_applications"."volunteer_id" IS 'Referência ao voluntário (FK → volunteers.id)';



COMMENT ON COLUMN "public"."vacancy_applications"."status" IS 'Status da candidatura: pending, accepted, rejected, withdrawn';



COMMENT ON COLUMN "public"."vacancy_applications"."applied_at" IS 'Data e hora em que o voluntário se candidatou';



COMMENT ON COLUMN "public"."vacancy_applications"."created_at" IS 'Data e hora de criação do registro';



COMMENT ON COLUMN "public"."vacancy_applications"."updated_at" IS 'Data e hora da última atualização (atualizado automaticamente por trigger)';



CREATE TABLE IF NOT EXISTS "public"."volunteers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "wp_post_id" integer,
    "owner_profile_id" "uuid",
    "name" "text" NOT NULL,
    "telefone" "text",
    "cidade" "text",
    "estado" "text",
    "profissao" "text",
    "escolaridade" "text",
    "faixa_etaria" "text",
    "genero" "text",
    "experiencia" "text",
    "atuacao" "text",
    "disponibilidade" "text",
    "periodo" "text",
    "descricao" "text",
    "comentarios" "text",
    "is_public" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "accept_terms" boolean DEFAULT true NOT NULL,
    "slug" "text"
);


ALTER TABLE "public"."volunteers" OWNER TO "postgres";


COMMENT ON COLUMN "public"."volunteers"."slug" IS 'URL-friendly identifier for volunteer profile. Generated from name or migrated from wp_posts_raw.post_name';



CREATE TABLE IF NOT EXISTS "public"."wp_postmeta_raw" (
    "meta_id" integer NOT NULL,
    "post_id" integer,
    "meta_key" "text",
    "meta_value" "text"
);


ALTER TABLE "public"."wp_postmeta_raw" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wp_posts_raw" (
    "id" integer NOT NULL,
    "post_author" integer,
    "post_date" timestamp with time zone,
    "post_date_gmt" timestamp with time zone,
    "post_content" "text",
    "post_title" "text",
    "post_excerpt" "text",
    "post_status" "text",
    "comment_status" "text",
    "ping_status" "text",
    "post_password" "text",
    "post_name" "text",
    "to_ping" "text",
    "pinged" "text",
    "post_modified" timestamp with time zone,
    "post_modified_gmt" timestamp with time zone,
    "post_content_filtered" "text",
    "post_parent" integer,
    "guid" "text",
    "menu_order" integer,
    "post_type" "text",
    "post_mime_type" "text",
    "comment_count" bigint
);


ALTER TABLE "public"."wp_posts_raw" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wp_usermeta_raw" (
    "umeta_id" bigint NOT NULL,
    "user_id" bigint NOT NULL,
    "meta_key" character varying(255),
    "meta_value" "text"
);


ALTER TABLE "public"."wp_usermeta_raw" OWNER TO "postgres";


COMMENT ON TABLE "public"."wp_usermeta_raw" IS 'Dump bruto da tabela wp_usermeta do WordPress - usado apenas para migração';



COMMENT ON COLUMN "public"."wp_usermeta_raw"."umeta_id" IS 'PK original do wp_usermeta';



CREATE SEQUENCE IF NOT EXISTS "public"."wp_usermeta_raw_meta_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."wp_usermeta_raw_meta_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."wp_usermeta_raw_meta_id_seq" OWNED BY "public"."wp_usermeta_raw"."umeta_id";



CREATE TABLE IF NOT EXISTS "public"."wp_users_legacy" (
    "id" integer NOT NULL,
    "user_login" "text" NOT NULL,
    "user_email" "text" NOT NULL,
    "user_pass" "text" NOT NULL,
    "display_name" "text",
    "migrated" boolean DEFAULT false NOT NULL,
    "migrated_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."wp_users_legacy" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wp_users_raw" (
    "id" integer NOT NULL,
    "user_login" "text" NOT NULL,
    "user_pass" "text" NOT NULL,
    "user_nicename" "text",
    "user_email" "text" NOT NULL,
    "user_url" "text",
    "user_registered" "text",
    "user_activation_key" "text",
    "user_status" integer,
    "display_name" "text"
);


ALTER TABLE "public"."wp_users_raw" OWNER TO "postgres";


ALTER TABLE ONLY "public"."wp_usermeta_raw" ALTER COLUMN "umeta_id" SET DEFAULT "nextval"('"public"."wp_usermeta_raw_meta_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_wp_user_id_key" UNIQUE ("wp_user_id");



ALTER TABLE ONLY "public"."shelter_dynamics"
    ADD CONSTRAINT "shelter_dynamics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shelter_history"
    ADD CONSTRAINT "shelter_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shelter_volunteers"
    ADD CONSTRAINT "shelter_volunteers_pkey" PRIMARY KEY ("shelter_id", "volunteer_id");



ALTER TABLE ONLY "public"."shelters"
    ADD CONSTRAINT "shelters_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shelters"
    ADD CONSTRAINT "shelters_wp_post_id_key" UNIQUE ("wp_post_id");



ALTER TABLE ONLY "public"."team_memberships"
    ADD CONSTRAINT "team_memberships_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_memberships"
    ADD CONSTRAINT "team_memberships_unique_member_per_shelter" UNIQUE ("owner_wp_user_id", "member_wp_user_id", "abrigo_post_id");



ALTER TABLE ONLY "public"."vacancy_applications"
    ADD CONSTRAINT "unique_volunteer_per_vacancy" UNIQUE ("vacancy_id", "volunteer_id");



ALTER TABLE ONLY "public"."vacancies"
    ADD CONSTRAINT "vacancies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vacancies"
    ADD CONSTRAINT "vacancies_wp_post_id_key" UNIQUE ("wp_post_id");



ALTER TABLE ONLY "public"."vacancy_applications"
    ADD CONSTRAINT "vacancy_applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."volunteers"
    ADD CONSTRAINT "volunteers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."volunteers"
    ADD CONSTRAINT "volunteers_wp_post_id_key" UNIQUE ("wp_post_id");



ALTER TABLE ONLY "public"."wp_postmeta_raw"
    ADD CONSTRAINT "wp_postmeta_raw_pkey" PRIMARY KEY ("meta_id");



ALTER TABLE ONLY "public"."wp_posts_raw"
    ADD CONSTRAINT "wp_posts_raw_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wp_usermeta_raw"
    ADD CONSTRAINT "wp_usermeta_raw_pkey" PRIMARY KEY ("umeta_id");



ALTER TABLE ONLY "public"."wp_users_legacy"
    ADD CONSTRAINT "wp_users_legacy_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wp_users_raw"
    ADD CONSTRAINT "wp_users_raw_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_profiles_email_lower" ON "public"."profiles" USING "btree" ("lower"("email"));



CREATE INDEX "idx_profiles_origin" ON "public"."profiles" USING "btree" ("origin");



CREATE INDEX "idx_profiles_role" ON "public"."profiles" USING "btree" ("role");



CREATE INDEX "idx_shelter_dynamics_shelter_id" ON "public"."shelter_dynamics" USING "btree" ("shelter_id");



CREATE INDEX "idx_shelter_history_changed_at" ON "public"."shelter_history" USING "btree" ("changed_at" DESC);



CREATE INDEX "idx_shelter_history_operation" ON "public"."shelter_history" USING "btree" ("operation");



CREATE INDEX "idx_shelter_history_profile_id" ON "public"."shelter_history" USING "btree" ("profile_id");



CREATE INDEX "idx_shelter_history_shelter_id" ON "public"."shelter_history" USING "btree" ("shelter_id");



CREATE INDEX "idx_shelter_volunteers_volunteer" ON "public"."shelter_volunteers" USING "btree" ("volunteer_id");



CREATE INDEX "idx_shelters_active" ON "public"."shelters" USING "btree" ("active");



COMMENT ON INDEX "public"."idx_shelters_active" IS 'Índice para filtros de abrigos ativos/inativos';



CREATE INDEX "idx_shelters_city_state" ON "public"."shelters" USING "btree" ("state", "city");



CREATE INDEX "idx_shelters_wp_post_author" ON "public"."shelters" USING "btree" ("wp_post_author") WHERE ("wp_post_author" IS NOT NULL);



CREATE INDEX "idx_shelters_wp_post_id" ON "public"."shelters" USING "btree" ("wp_post_id");



CREATE INDEX "idx_vacancies_city_state" ON "public"."vacancies" USING "btree" ("estado", "cidade");



CREATE INDEX "idx_vacancies_shelter" ON "public"."vacancies" USING "btree" ("shelter_id");



CREATE UNIQUE INDEX "idx_vacancies_slug" ON "public"."vacancies" USING "btree" ("slug");



COMMENT ON INDEX "public"."idx_vacancies_slug" IS 'Unique index for vacancy slugs. Ensures fast lookups and prevents duplicates.';



CREATE INDEX "idx_vacancies_wp_post_id" ON "public"."vacancies" USING "btree" ("wp_post_id");



COMMENT ON INDEX "public"."idx_vacancies_wp_post_id" IS 'Index for tracking WordPress post ID during migration.';



CREATE INDEX "idx_vacancy_applications_applied_at" ON "public"."vacancy_applications" USING "btree" ("applied_at" DESC);



CREATE INDEX "idx_vacancy_applications_status" ON "public"."vacancy_applications" USING "btree" ("status");



CREATE INDEX "idx_vacancy_applications_vacancy_id" ON "public"."vacancy_applications" USING "btree" ("vacancy_id");



CREATE INDEX "idx_vacancy_applications_volunteer_id" ON "public"."vacancy_applications" USING "btree" ("volunteer_id");



CREATE INDEX "idx_volunteers_city_state" ON "public"."volunteers" USING "btree" ("estado", "cidade");



CREATE UNIQUE INDEX "idx_volunteers_slug" ON "public"."volunteers" USING "btree" ("slug");



COMMENT ON INDEX "public"."idx_volunteers_slug" IS 'Unique index for volunteer slugs. Ensures fast lookups and prevents duplicates.';



CREATE INDEX "idx_volunteers_wp_post_id" ON "public"."volunteers" USING "btree" ("wp_post_id");



CREATE INDEX "idx_wp_usermeta_raw_key" ON "public"."wp_usermeta_raw" USING "btree" ("meta_key");



CREATE INDEX "idx_wp_usermeta_raw_user" ON "public"."wp_usermeta_raw" USING "btree" ("user_id");



CREATE INDEX "idx_wp_usermeta_raw_userkey" ON "public"."wp_usermeta_raw" USING "btree" ("user_id", "meta_key");



CREATE INDEX "idx_wp_users_legacy_email" ON "public"."wp_users_legacy" USING "btree" ("lower"("user_email"));



CREATE UNIQUE INDEX "shelter_dynamics_unique_ref" ON "public"."shelter_dynamics" USING "btree" ("shelter_id", "dynamic_type", "reference_period");



CREATE UNIQUE INDEX "shelters_profile_id_key" ON "public"."shelters" USING "btree" ("profile_id");



CREATE INDEX "team_memberships_member_email_idx" ON "public"."team_memberships" USING "btree" ("member_email");



CREATE UNIQUE INDEX "team_memberships_owner_member_uniq" ON "public"."team_memberships" USING "btree" ("owner_wp_user_id", "member_wp_user_id");



CREATE INDEX "team_memberships_pending_owner_idx" ON "public"."team_memberships" USING "btree" ("status") WHERE ("status" = 'pending_owner'::"text");



CREATE OR REPLACE TRIGGER "set_timestamp_profiles" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_timestamp"();



CREATE OR REPLACE TRIGGER "set_timestamp_shelter_volunteers" BEFORE UPDATE ON "public"."shelter_volunteers" FOR EACH ROW EXECUTE FUNCTION "public"."set_timestamp"();



CREATE OR REPLACE TRIGGER "set_timestamp_shelters" BEFORE UPDATE ON "public"."shelters" FOR EACH ROW EXECUTE FUNCTION "public"."set_timestamp"();



CREATE OR REPLACE TRIGGER "set_timestamp_vacancies" BEFORE UPDATE ON "public"."vacancies" FOR EACH ROW EXECUTE FUNCTION "public"."set_timestamp"();



CREATE OR REPLACE TRIGGER "set_timestamp_volunteers" BEFORE UPDATE ON "public"."volunteers" FOR EACH ROW EXECUTE FUNCTION "public"."set_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_shelter_history" AFTER INSERT OR DELETE OR UPDATE ON "public"."shelters" FOR EACH ROW EXECUTE FUNCTION "public"."log_shelter_changes"();



COMMENT ON TRIGGER "trigger_shelter_history" ON "public"."shelters" IS 'Captura automaticamente mudanças em shelters';



CREATE OR REPLACE TRIGGER "vacancy_applications_updated_at" BEFORE UPDATE ON "public"."vacancy_applications" FOR EACH ROW EXECUTE FUNCTION "public"."update_vacancy_applications_updated_at"();



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shelter_dynamics"
    ADD CONSTRAINT "shelter_dynamics_shelter_id_fkey" FOREIGN KEY ("shelter_id") REFERENCES "public"."shelters"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shelter_history"
    ADD CONSTRAINT "shelter_history_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shelter_history"
    ADD CONSTRAINT "shelter_history_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shelter_history"
    ADD CONSTRAINT "shelter_history_shelter_id_fkey" FOREIGN KEY ("shelter_id") REFERENCES "public"."shelters"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shelter_volunteers"
    ADD CONSTRAINT "shelter_volunteers_shelter_id_fkey" FOREIGN KEY ("shelter_id") REFERENCES "public"."shelters"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shelter_volunteers"
    ADD CONSTRAINT "shelter_volunteers_volunteer_id_fkey" FOREIGN KEY ("volunteer_id") REFERENCES "public"."volunteers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shelters"
    ADD CONSTRAINT "shelters_owner_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shelters"
    ADD CONSTRAINT "shelters_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vacancies"
    ADD CONSTRAINT "vacancies_shelter_id_fkey" FOREIGN KEY ("shelter_id") REFERENCES "public"."shelters"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vacancy_applications"
    ADD CONSTRAINT "vacancy_applications_vacancy_id_fkey" FOREIGN KEY ("vacancy_id") REFERENCES "public"."vacancies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vacancy_applications"
    ADD CONSTRAINT "vacancy_applications_volunteer_id_fkey" FOREIGN KEY ("volunteer_id") REFERENCES "public"."volunteers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."volunteers"
    ADD CONSTRAINT "volunteers_owner_profile_id_fkey" FOREIGN KEY ("owner_profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



CREATE POLICY "Service role has full access to applications" ON "public"."vacancy_applications" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Shelter dynamics are viewable by everyone" ON "public"."shelter_dynamics" FOR SELECT USING (true);



CREATE POLICY "Shelter volunteers are viewable by everyone" ON "public"."shelter_volunteers" FOR SELECT USING (true);



CREATE POLICY "Shelters are viewable by everyone" ON "public"."shelters" FOR SELECT USING (true);



CREATE POLICY "Shelters can view applications to their vacancies" ON "public"."vacancy_applications" FOR SELECT USING (("vacancy_id" IN ( SELECT "vacancies"."id"
   FROM "public"."vacancies"
  WHERE ("vacancies"."shelter_id" IN ( SELECT "shelters"."id"
           FROM "public"."shelters"
          WHERE ("shelters"."profile_id" = "auth"."uid"()))))));



CREATE POLICY "System can insert shelter history" ON "public"."shelter_history" FOR INSERT WITH CHECK (true);



CREATE POLICY "Team memberships deletable by service role" ON "public"."team_memberships" FOR DELETE USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Team memberships readable by service role" ON "public"."team_memberships" FOR SELECT USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Team memberships updatable by service role" ON "public"."team_memberships" FOR UPDATE USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Team memberships writable by service role" ON "public"."team_memberships" FOR INSERT WITH CHECK (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Users can update their own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view their own profile" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view their own shelter history" ON "public"."shelter_history" FOR SELECT USING (("auth"."uid"() = "profile_id"));



CREATE POLICY "Vacancies are viewable by everyone" ON "public"."vacancies" FOR SELECT USING (true);



CREATE POLICY "Volunteers are viewable by everyone" ON "public"."volunteers" FOR SELECT USING (true);



CREATE POLICY "Volunteers can view their own applications" ON "public"."vacancy_applications" FOR SELECT USING (("volunteer_id" IN ( SELECT "volunteers"."id"
   FROM "public"."volunteers"
  WHERE ("volunteers"."owner_profile_id" = "auth"."uid"()))));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_select_own" ON "public"."profiles" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



ALTER TABLE "public"."shelter_dynamics" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shelter_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shelter_volunteers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shelter_volunteers_select_public" ON "public"."shelter_volunteers" FOR SELECT USING (true);



ALTER TABLE "public"."shelters" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shelters_select_public" ON "public"."shelters" FOR SELECT USING (true);



ALTER TABLE "public"."team_memberships" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vacancies" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "vacancies_select_public" ON "public"."vacancies" FOR SELECT USING (true);



ALTER TABLE "public"."vacancy_applications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."volunteers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "volunteers_select_public" ON "public"."volunteers" FOR SELECT USING (true);



ALTER TABLE "public"."wp_postmeta_raw" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wp_posts_raw" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wp_usermeta_raw" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wp_users_legacy" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wp_users_raw" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."log_shelter_changes"() TO "anon";
GRANT ALL ON FUNCTION "public"."log_shelter_changes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_shelter_changes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_vacancy_applications_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_vacancy_applications_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_vacancy_applications_updated_at"() TO "service_role";


















GRANT ALL ON TABLE "public"."profiles" TO "service_role";
GRANT SELECT,UPDATE ON TABLE "public"."profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."shelter_dynamics" TO "anon";
GRANT ALL ON TABLE "public"."shelter_dynamics" TO "authenticated";
GRANT ALL ON TABLE "public"."shelter_dynamics" TO "service_role";



GRANT ALL ON TABLE "public"."shelter_history" TO "anon";
GRANT ALL ON TABLE "public"."shelter_history" TO "authenticated";
GRANT ALL ON TABLE "public"."shelter_history" TO "service_role";



GRANT ALL ON TABLE "public"."shelter_volunteers" TO "service_role";
GRANT SELECT ON TABLE "public"."shelter_volunteers" TO "anon";
GRANT SELECT ON TABLE "public"."shelter_volunteers" TO "authenticated";



GRANT ALL ON TABLE "public"."shelters" TO "service_role";
GRANT SELECT ON TABLE "public"."shelters" TO "anon";
GRANT SELECT ON TABLE "public"."shelters" TO "authenticated";



GRANT ALL ON TABLE "public"."team_memberships" TO "service_role";



GRANT ALL ON TABLE "public"."vacancies" TO "service_role";
GRANT SELECT ON TABLE "public"."vacancies" TO "anon";
GRANT SELECT ON TABLE "public"."vacancies" TO "authenticated";



GRANT ALL ON TABLE "public"."vacancy_applications" TO "anon";
GRANT ALL ON TABLE "public"."vacancy_applications" TO "authenticated";
GRANT ALL ON TABLE "public"."vacancy_applications" TO "service_role";



GRANT ALL ON TABLE "public"."volunteers" TO "service_role";
GRANT SELECT ON TABLE "public"."volunteers" TO "anon";
GRANT SELECT ON TABLE "public"."volunteers" TO "authenticated";



GRANT ALL ON TABLE "public"."wp_postmeta_raw" TO "service_role";



GRANT ALL ON TABLE "public"."wp_posts_raw" TO "service_role";



GRANT ALL ON TABLE "public"."wp_usermeta_raw" TO "service_role";



GRANT ALL ON SEQUENCE "public"."wp_usermeta_raw_meta_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."wp_usermeta_raw_meta_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."wp_usermeta_raw_meta_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."wp_users_legacy" TO "service_role";



GRANT ALL ON TABLE "public"."wp_users_raw" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































