BEGIN;

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

ALTER TABLE IF EXISTS ONLY auth.users_groups DROP CONSTRAINT IF EXISTS usr_id_fk;
ALTER TABLE IF EXISTS ONLY auth.sessions DROP CONSTRAINT IF EXISTS usr_id_fk;
ALTER TABLE IF EXISTS ONLY auth.groups_policies DROP CONSTRAINT IF EXISTS unit_id_fk;
ALTER TABLE IF EXISTS ONLY auth.users_groups DROP CONSTRAINT IF EXISTS grp_id_fk;
ALTER TABLE IF EXISTS ONLY auth.groups_policies DROP CONSTRAINT IF EXISTS grp_id_fk;
ALTER TABLE IF EXISTS ONLY auth.users DROP CONSTRAINT IF EXISTS users_uq;
ALTER TABLE IF EXISTS ONLY auth.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY auth.users_groups DROP CONSTRAINT IF EXISTS users_groups_pkey;
ALTER TABLE IF EXISTS ONLY auth.units DROP CONSTRAINT IF EXISTS units_uq;
ALTER TABLE IF EXISTS ONLY auth.units DROP CONSTRAINT IF EXISTS units_pkey;
ALTER TABLE IF EXISTS ONLY auth.sessions DROP CONSTRAINT IF EXISTS sessions_pkey;
ALTER TABLE IF EXISTS ONLY auth.groups DROP CONSTRAINT IF EXISTS groups_uq;
ALTER TABLE IF EXISTS ONLY auth.groups_policies DROP CONSTRAINT IF EXISTS groups_policies_uq;
ALTER TABLE IF EXISTS ONLY auth.groups_policies DROP CONSTRAINT IF EXISTS groups_policies_pkey;
ALTER TABLE IF EXISTS ONLY auth.groups DROP CONSTRAINT IF EXISTS groups_pkey;
ALTER TABLE IF EXISTS auth.users_groups ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS auth.users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS auth.units ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS auth.sessions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS auth.groups_policies ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS auth.groups ALTER COLUMN id DROP DEFAULT;
DROP VIEW IF EXISTS auth.users_without_groups;
DROP VIEW IF EXISTS auth.users_in_groups;
DROP SEQUENCE IF EXISTS auth.users_id_seq;
DROP SEQUENCE IF EXISTS auth.users_groups_id_seq;
DROP TABLE IF EXISTS auth.users_groups;
DROP TABLE IF EXISTS auth.users;
DROP SEQUENCE IF EXISTS auth.units_id_seq;
DROP TABLE IF EXISTS auth.units;
DROP SEQUENCE IF EXISTS auth.sessions_id_seq;
DROP TABLE IF EXISTS auth.sessions;
DROP SEQUENCE IF EXISTS auth.groups_policies_id_seq;
DROP TABLE IF EXISTS auth.groups_policies;
DROP SEQUENCE IF EXISTS auth.groups_id_seq;
DROP TABLE IF EXISTS auth.groups;
DROP SCHEMA IF EXISTS auth;

CREATE SCHEMA auth;

ALTER SCHEMA auth OWNER TO ${owner};

SET default_tablespace = '';

SET default_table_access_method = heap;

CREATE TABLE auth.groups (
    id integer NOT NULL,
    grp_name character varying NOT NULL,
    "description" character varying(255) DEFAULT ''
);


ALTER TABLE auth.groups OWNER TO ${owner};

CREATE SEQUENCE auth.groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth.groups_id_seq OWNER TO ${owner};

ALTER SEQUENCE auth.groups_id_seq OWNED BY auth.groups.id;

CREATE TABLE auth.groups_policies (
    id integer NOT NULL,
    grp_id integer NOT NULL,
    unit_id integer NOT NULL,
    r_p boolean,
    w_p boolean
);


ALTER TABLE auth.groups_policies OWNER TO ${owner};

CREATE SEQUENCE auth.groups_policies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth.groups_policies_id_seq OWNER TO ${owner};

ALTER SEQUENCE auth.groups_policies_id_seq OWNED BY auth.groups_policies.id;

CREATE TABLE auth.sessions (
    id integer NOT NULL,
    usr_id integer NOT NULL,
    r_token character varying(255) NOT NULL,
    a_exp bigint NOT NULL,
    v_code1 character varying(10) NOT NULL,
    v_code2 character varying(10) NOT NULL,
    active boolean
);


ALTER TABLE auth.sessions OWNER TO ${owner};

CREATE SEQUENCE auth.sessions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth.sessions_id_seq OWNER TO ${owner};

ALTER SEQUENCE auth.sessions_id_seq OWNED BY auth.sessions.id;

CREATE TABLE auth.units (
    id integer NOT NULL,
    unit_name character varying(255) NOT NULL,
    exports json DEFAULT '{}'::json
);


ALTER TABLE auth.units OWNER TO ${owner};

CREATE SEQUENCE auth.units_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth.units_id_seq OWNER TO ${owner};

ALTER SEQUENCE auth.units_id_seq OWNED BY auth.units.id;

CREATE TABLE auth.users (
    id integer NOT NULL,
    usr_name character varying(255) NOT NULL,
    passwd character varying(258) NOT NULL
);


ALTER TABLE auth.users OWNER TO ${owner};

CREATE TABLE auth.users_groups (
    id integer NOT NULL,
    usr_id integer NOT NULL,
    grp_id integer NOT NULL
);


ALTER TABLE auth.users_groups OWNER TO ${owner};

CREATE SEQUENCE auth.users_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth.users_groups_id_seq OWNER TO ${owner};

ALTER SEQUENCE auth.users_groups_id_seq OWNED BY auth.users_groups.id;

CREATE SEQUENCE auth.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth.users_id_seq OWNER TO ${owner};

ALTER SEQUENCE auth.users_id_seq OWNED BY auth.users.id;

CREATE VIEW auth.users_in_groups AS
 SELECT users_groups.id,
    users.id AS usr_id,
    groups.id AS grp_id,
    users.usr_name,
    groups.grp_name
   FROM auth.users_groups,
    auth.users,
    auth.groups
  WHERE ((users.id = users_groups.usr_id) AND (groups.id = users_groups.grp_id));


ALTER TABLE auth.users_in_groups OWNER TO ${owner};

CREATE VIEW auth.users_without_groups AS
 SELECT users.id,
    users.usr_name
   FROM auth.users
  WHERE (NOT (users.id IN ( SELECT users_groups.usr_id
           FROM auth.users_groups
          GROUP BY users_groups.usr_id)));


ALTER TABLE auth.users_without_groups OWNER TO ${owner};

ALTER TABLE ONLY auth.groups ALTER COLUMN id SET DEFAULT nextval('auth.groups_id_seq'::regclass);

ALTER TABLE ONLY auth.groups_policies ALTER COLUMN id SET DEFAULT nextval('auth.groups_policies_id_seq'::regclass);

ALTER TABLE ONLY auth.sessions ALTER COLUMN id SET DEFAULT nextval('auth.sessions_id_seq'::regclass);

ALTER TABLE ONLY auth.units ALTER COLUMN id SET DEFAULT nextval('auth.units_id_seq'::regclass);

ALTER TABLE ONLY auth.users ALTER COLUMN id SET DEFAULT nextval('auth.users_id_seq'::regclass);

ALTER TABLE ONLY auth.users_groups ALTER COLUMN id SET DEFAULT nextval('auth.users_groups_id_seq'::regclass);

ALTER TABLE ONLY auth.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);

ALTER TABLE ONLY auth.groups_policies
    ADD CONSTRAINT groups_policies_pkey PRIMARY KEY (id);

ALTER TABLE ONLY auth.groups_policies
    ADD CONSTRAINT groups_policies_uq UNIQUE (grp_id, unit_id);

ALTER TABLE ONLY auth.groups
    ADD CONSTRAINT groups_uq UNIQUE (grp_name);

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);

ALTER TABLE ONLY auth.units
    ADD CONSTRAINT units_pkey PRIMARY KEY (id);

ALTER TABLE ONLY auth.units
    ADD CONSTRAINT units_uq UNIQUE (unit_name);

ALTER TABLE ONLY auth.users_groups
    ADD CONSTRAINT users_groups_pkey PRIMARY KEY (id);

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_uq UNIQUE (usr_name);

ALTER TABLE ONLY auth.groups_policies
    ADD CONSTRAINT grp_id_fk FOREIGN KEY (grp_id) REFERENCES auth.groups(id) MATCH FULL ON DELETE CASCADE;

ALTER TABLE ONLY auth.users_groups
    ADD CONSTRAINT grp_id_fk FOREIGN KEY (grp_id) REFERENCES auth.groups(id) MATCH FULL ON DELETE CASCADE;

ALTER TABLE ONLY auth.groups_policies
    ADD CONSTRAINT unit_id_fk FOREIGN KEY (unit_id) REFERENCES auth.units(id) MATCH FULL ON DELETE CASCADE;

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT usr_id_fk FOREIGN KEY (usr_id) REFERENCES auth.users(id) MATCH FULL ON DELETE CASCADE;

ALTER TABLE ONLY auth.users_groups
    ADD CONSTRAINT usr_id_fk FOREIGN KEY (usr_id) REFERENCES auth.users(id) MATCH FULL ON DELETE CASCADE;

COMMIT;