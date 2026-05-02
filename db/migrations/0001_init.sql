DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'eve_stats_app') THEN
        CREATE ROLE eve_stats_app
            LOGIN
            PASSWORD '$AppPassword$'
            CONNECTION LIMIT -1;
    END IF;
END
$$;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;

GRANT ALL ON SCHEMA public TO eve_stats_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES    TO eve_stats_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON SEQUENCES TO eve_stats_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON FUNCTIONS TO eve_stats_app;
