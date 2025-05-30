-- Основная таблица адресов
CREATE TABLE IF NOT EXISTS message_address (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created TIMESTAMP(0) NOT NULL,
    address VARCHAR NOT NULL UNIQUE
);
CREATE INDEX IF NOT EXISTS message_address_id_idx ON message_address (id);
CREATE INDEX IF NOT EXISTS message_address_address_idx ON message_address (address);

-- Bounce-события
CREATE TABLE IF NOT EXISTS message_bounce (
    created TIMESTAMP(0) NOT NULL,
    int_id CHAR(16) NOT NULL,
    address_id INTEGER REFERENCES message_address(id),
    o_id CHAR(16) NOT NULL,
    str VARCHAR NOT NULL
);
CREATE INDEX IF NOT EXISTS message_bounce_created_idx ON message_bounce (created);

-- Основные сообщения (<=)
CREATE TABLE IF NOT EXISTS message (
    created TIMESTAMP(0) NOT NULL,
    id VARCHAR NOT NULL,
    int_id CHAR(16) NOT NULL,
    str VARCHAR NOT NULL,
    status BOOL,
    address_id INTEGER REFERENCES message_address(id),
    o_id CHAR(16) NOT NULL,
    CONSTRAINT message_id_pk PRIMARY KEY(id)
);
CREATE INDEX IF NOT EXISTS message_address_idx ON message (address_id);
CREATE INDEX IF NOT EXISTS message_created_idx ON message (created);
CREATE INDEX IF NOT EXISTS message_int_id_idx ON message (int_id);

-- Прочие лог-события
CREATE TABLE IF NOT EXISTS log (
    created TIMESTAMP(0) NOT NULL,
    int_id CHAR(16) NOT NULL,
    str VARCHAR NOT NULL,
    address_id INTEGER REFERENCES message_address(id),
    o_id int NOT NULL
);
CREATE INDEX IF NOT EXISTS log_address_idx ON log (address_id);

-- специальная таблица для переменных
-- первая и пока единственная переменная - 
-- сквозной счётчик появления записей в таблицах message, message_bounce, log
CREATE TABLE IF NOT EXISTS vars (
    n CHAR(16) NOT NULL,
    v int_id CHAR(16) NOT NULL,
    CONSTRAINT vars_n_pk PRIMARY KEY(n)
);
insert into vars (n, v) values ('o_id', '$OIDSTART');