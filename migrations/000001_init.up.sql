CREATE SCHEMA todoapp;

CREATE TABLE todoapp.users
(
    id           SERIAL PRIMARY KEY,
    version      BIGINT       NOT NULL DEFAULT 1,
    full_name    VARCHAR(100) NOT NULL CHECK ( CHAR_LENGTH(full_name) BETWEEN 3 AND 100),
    phone_number VARCHAR(15) CHECK (
        phone_number ~ '^\+[0-9]+$'
            AND
        CHAR_LENGTH(full_name) BETWEEN 10 AND 15
        )
);

CREATE TABLE todoapp.tasks
(
    id             SERIAL PRIMARY KEY,
    version        BIGINT       NOT NULL DEFAULT 1,
    title          VARCHAR(100) NOT NULL CHECK (char_length(title) BETWEEN 1 AND 100),
    description    VARCHAR(1000) CHECK (char_length(title) BETWEEN 1 AND 1000),
    completed      BOOLEAN      NOT NULL,
    created_at     timestamptz  NOT NULL,
    completed_at   timestamptz,
    author_user_id INT          NOT NULL REFERENCES todoapp.users (id)
        CHECK (
            (completed = FALSE AND completed_at IS NULL)
                OR
            (completed = TRUE AND completed_at IS NOT NULL AND completed_at >= created_at)
            )

)