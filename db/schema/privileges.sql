-- Current state of role and schema privileges.
-- Hand-maintained reference — never executed by DbUp.

-- Application role: full access to all schema objects.
CREATE ROLE eve_stats_app
    LOGIN
    CONNECTION LIMIT -1;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;

GRANT ALL ON SCHEMA public TO eve_stats_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES    TO eve_stats_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON SEQUENCES TO eve_stats_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON FUNCTIONS TO eve_stats_app;

-- Read-only role: used by the MCP server for LLM-driven queries.
CREATE ROLE eve_stats_readonly
    LOGIN
    CONNECTION LIMIT -1;

GRANT CONNECT ON DATABASE eve_stats TO eve_stats_readonly;
GRANT USAGE  ON SCHEMA  public     TO eve_stats_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES    TO eve_stats_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON SEQUENCES TO eve_stats_readonly;
