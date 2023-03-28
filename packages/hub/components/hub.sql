--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.3
-- Dumped by pg_dump version 9.5.3

-- Started on 2016-08-07 20:50:18 MSK

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 8 (class 2615 OID 16478)
-- Name: hub; Type: SCHEMA; Schema: -; Owner: nef
--

CREATE SCHEMA hub;


ALTER SCHEMA hub OWNER TO nef;

SET search_path = hub, pg_catalog;

SET default_with_oids = false;

--
-- TOC entry 197 (class 1259 OID 16489)
-- Name: menu; Type: TABLE; Schema: hub; Owner: nef
--

CREATE TABLE menu (
    id integer NOT NULL,
    category_id integer NOT NULL,
    unit_id integer NOT NULL,
    item_name json DEFAULT '{"en":""}'::json NOT NULL
);


ALTER TABLE menu OWNER TO nef;

--
-- TOC entry 195 (class 1259 OID 16481)
-- Name: menu_categories; Type: TABLE; Schema: hub; Owner: nef
--

CREATE TABLE menu_categories (
    id integer NOT NULL,
    category_name json DEFAULT '{"en":""}'::json NOT NULL
);


ALTER TABLE menu_categories OWNER TO nef;

--
-- TOC entry 194 (class 1259 OID 16479)
-- Name: menu_categories_id_seq; Type: SEQUENCE; Schema: hub; Owner: nef
--

CREATE SEQUENCE menu_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menu_categories_id_seq OWNER TO nef;

--
-- TOC entry 2192 (class 0 OID 0)
-- Dependencies: 194
-- Name: menu_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: hub; Owner: nef
--

ALTER SEQUENCE menu_categories_id_seq OWNED BY menu_categories.id;


--
-- TOC entry 196 (class 1259 OID 16487)
-- Name: menu_id_seq; Type: SEQUENCE; Schema: hub; Owner: nef
--

CREATE SEQUENCE menu_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE menu_id_seq OWNER TO nef;

--
-- TOC entry 2193 (class 0 OID 0)
-- Dependencies: 196
-- Name: menu_id_seq; Type: SEQUENCE OWNED BY; Schema: hub; Owner: nef
--

ALTER SEQUENCE menu_id_seq OWNED BY menu.id;


--
-- TOC entry 2063 (class 2604 OID 16492)
-- Name: id; Type: DEFAULT; Schema: hub; Owner: nef
--

ALTER TABLE ONLY menu ALTER COLUMN id SET DEFAULT nextval('menu_id_seq'::regclass);


--
-- TOC entry 2061 (class 2604 OID 16484)
-- Name: id; Type: DEFAULT; Schema: hub; Owner: nef
--

ALTER TABLE ONLY menu_categories ALTER COLUMN id SET DEFAULT nextval('menu_categories_id_seq'::regclass);


--
-- TOC entry 2068 (class 2606 OID 16653)
-- Name: category_unit_uq; Type: CONSTRAINT; Schema: hub; Owner: nef
--

ALTER TABLE ONLY menu
    ADD CONSTRAINT category_unit_uq UNIQUE (category_id, unit_id);


--
-- TOC entry 2066 (class 2606 OID 16486)
-- Name: menu_categories_pk; Type: CONSTRAINT; Schema: hub; Owner: nef
--

ALTER TABLE ONLY menu_categories
    ADD CONSTRAINT menu_categories_pk PRIMARY KEY (id);


--
-- TOC entry 2070 (class 2606 OID 16494)
-- Name: menu_pk; Type: CONSTRAINT; Schema: hub; Owner: nef
--

ALTER TABLE ONLY menu
    ADD CONSTRAINT menu_pk PRIMARY KEY (id);


--
-- TOC entry 2071 (class 2606 OID 16497)
-- Name: category_id_fk; Type: FK CONSTRAINT; Schema: hub; Owner: nef
--

ALTER TABLE ONLY menu
    ADD CONSTRAINT category_id_fk FOREIGN KEY (category_id) REFERENCES menu_categories(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2072 (class 2606 OID 16503)
-- Name: unit_id_fk; Type: FK CONSTRAINT; Schema: hub; Owner: nef
--

ALTER TABLE ONLY menu
    ADD CONSTRAINT unit_id_fk FOREIGN KEY (unit_id) REFERENCES auth.units(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2191 (class 0 OID 0)
-- Dependencies: 8
-- Name: hub; Type: ACL; Schema: -; Owner: nef
--

REVOKE ALL ON SCHEMA hub FROM PUBLIC;


-- Completed on 2016-08-07 20:50:19 MSK

--
-- PostgreSQL database dump complete
--

