BEGIN;
SET client_min_messages TO 'WARNING';

TRUNCATE editor CASCADE;
TRUNCATE label CASCADE;
TRUNCATE label_name CASCADE;

COMMIT;