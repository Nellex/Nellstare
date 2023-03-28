PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE package_status (status VARCHAR (40) PRIMARY KEY UNIQUE NOT NULL);
INSERT INTO package_status VALUES('installed');
INSERT INTO package_status VALUES('locked');
CREATE TABLE packages (name VARCHAR (255) PRIMARY KEY UNIQUE NOT NULL, version INTEGER NOT NULL, hash VARCHAR (255) UNIQUE NOT NULL, status REFERENCES package_status (status) ON DELETE CASCADE ON UPDATE CASCADE MATCH FULL);
CREATE TABLE config (property VARCHAR (255) UNIQUE NOT NULL PRIMARY KEY, value VARCHAR (255) NOT NULL);
INSERT INTO config VALUES('lang','ru');
INSERT INTO config VALUES('scheme','https');
INSERT INTO config VALUES('base_url','localhost:8443');
INSERT INTO config VALUES('scontroller_url','/scontroller');
INSERT INTO config VALUES('css_url','https://localhost:8443/css');
INSERT INTO config VALUES('js_url','https://localhost:8443/js');
INSERT INTO config VALUES('project_priority','1');
INSERT INTO config VALUES('host','127.0.0.1');
INSERT INTO config VALUES('port','8193');
INSERT INTO config VALUES('nefsrv_port','8444');
INSERT INTO config VALUES('debug_mode','true');
INSERT INTO config VALUES('server_name','Server 1');
INSERT INTO config VALUES('use_db','true');
INSERT INTO config VALUES('db_host','127.0.0.1');
INSERT INTO config VALUES('db_port','5432');
INSERT INTO config VALUES('db_name','nef');
INSERT INTO config VALUES('db_user','nef');
INSERT INTO config VALUES('db_password','test');
INSERT INTO config VALUES('server_secret','WZNeuWJAhy8UsN');
INSERT INTO config VALUES('nefsrv_secret','MYY6rTjBrZIWkr');
INSERT INTO config VALUES('route_token','xaax09euwns436');
INSERT INTO config VALUES('use_setuid','true');
INSERT INTO config VALUES('nef_uid','121');
INSERT INTO config VALUES('bcrypt_rounds','12');
INSERT INTO config VALUES('session_lifetime','30');
INSERT INTO config VALUES('refresh_lifetime','3');
CREATE TABLE acl_sources (
    type VARCHAR (255) PRIMARY KEY
                     UNIQUE
                     NOT NULL
);
INSERT INTO acl_sources VALUES('constant');
INSERT INTO acl_sources VALUES('module');
INSERT INTO acl_sources VALUES('service');
CREATE TABLE acl_targets (
    type VARCHAR (255) PRIMARY KEY
                     UNIQUE
                     NOT NULL
);
INSERT INTO acl_targets VALUES('constant');
INSERT INTO acl_targets VALUES('signal');
INSERT INTO acl_targets VALUES('event');
INSERT INTO acl_targets VALUES('module');
INSERT INTO acl_targets VALUES('service');
CREATE TABLE acl (package REFERENCES packages (name) ON DELETE CASCADE ON UPDATE CASCADE MATCH FULL, source_type REFERENCES acl_sources (type) ON DELETE CASCADE ON UPDATE CASCADE MATCH FULL, source VARCHAR (255) NOT NULL, target_type REFERENCES acl_targets (type) ON DELETE CASCADE ON UPDATE CASCADE MATCH FULL, target VARCHAR (255) NOT NULL);
CREATE TABLE autoload_modules (package REFERENCES packages (name) ON DELETE CASCADE ON UPDATE CASCADE MATCH FULL NOT NULL, module_name VARCHAR (255) NOT NULL);
CREATE TABLE projects (name VARCHAR (255) UNIQUE NOT NULL PRIMARY KEY);
CREATE TABLE key_store (package REFERENCES packages (name) ON DELETE CASCADE ON UPDATE CASCADE MATCH FULL NOT NULL, "key" VARCHAR (255) NOT NULL, value VARCHAR (524) NOT NULL);
CREATE TABLE dependencies (package VARCHAR REFERENCES packages (name) ON DELETE CASCADE ON UPDATE CASCADE MATCH FULL NOT DEFERRABLE NOT NULL, dep_package VARCHAR REFERENCES packages (name) ON DELETE CASCADE ON UPDATE CASCADE MATCH FULL NOT DEFERRABLE NOT NULL, PRIMARY KEY (package COLLATE RTRIM ASC, dep_package COLLATE RTRIM ASC) ON CONFLICT ABORT);
CREATE TRIGGER acl_module_chk_update BEFORE UPDATE ON acl FOR EACH ROW WHEN NEW.source_type = 'module' BEGIN select raise(ABORT, 'modules can`t calls events!') where NEW.target_type = 'event'; END;
CREATE TRIGGER acl_service_chk_update BEFORE UPDATE ON acl FOR EACH ROW WHEN NEW.source_type = 'service' BEGIN select raise(ABORT, 'services can`t calls signals!') where NEW.target_type = 'signal'; END;
CREATE TRIGGER acl_service_chk_insert BEFORE INSERT ON acl FOR EACH ROW WHEN NEW.source_type = 'service' BEGIN select raise(ABORT, 'services can`t calls signals!') where NEW.target_type = 'signal'
; END;
CREATE TRIGGER acl_module_chk_insert BEFORE INSERT ON acl FOR EACH ROW WHEN NEW.source_type = 'module' BEGIN select raise(ABORT, 'modules can`t calls events!') where NEW.target_type = 'event'; END;
CREATE UNIQUE INDEX key_store_uq ON key_store (package COLLATE BINARY ASC, "key" COLLATE BINARY ASC);
CREATE UNIQUE INDEX pidx ON acl (package COLLATE BINARY COLLATE BINARY ASC, source COLLATE BINARY COLLATE BINARY ASC, target COLLATE BINARY COLLATE BINARY ASC);
COMMIT;
