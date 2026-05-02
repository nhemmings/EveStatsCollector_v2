DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'eve_stats_readonly') THEN
        CREATE ROLE eve_stats_readonly
            LOGIN
            PASSWORD '$ReadonlyPassword$'
            CONNECTION LIMIT -1;
    END IF;
END
$$;

GRANT CONNECT ON DATABASE eve_stats TO eve_stats_readonly;
GRANT USAGE  ON SCHEMA  public     TO eve_stats_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES    TO eve_stats_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON SEQUENCES TO eve_stats_readonly;
