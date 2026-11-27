-- Apply to a new UserDB with a migration/admin identity; runtime app credentials should have only required DML access.
-- Do not use this to overwrite a database containing legacy plaintext passwords.
CREATE TABLE IF NOT EXISTS Employee (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    username VARCHAR(40) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    regdate TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
