-- Основная таблица адресов
CREATE TABLE IF NOT EXISTS message_address (
    id INT AUTO_INCREMENT PRIMARY KEY,
    created TIMESTAMP NOT NULL,
    address VARCHAR(255) NOT NULL UNIQUE
);

CREATE INDEX message_address_id_idx ON message_address (id);
CREATE INDEX message_address_address_idx ON message_address (address);

-- Bounce-события
CREATE TABLE IF NOT EXISTS message_bounce (
    created TIMESTAMP NOT NULL,
    int_id CHAR(16) NOT NULL,
    address_id INT,
    o_id CHAR(16) NOT NULL,
    str VARCHAR(4096) NOT NULL,
    FOREIGN KEY (address_id) REFERENCES message_address(id)
);

CREATE INDEX message_bounce_created_idx ON message_bounce (created);

-- Основные сообщения
CREATE TABLE IF NOT EXISTS message (
    created TIMESTAMP NOT NULL,
    id VARCHAR(255) NOT NULL,
    int_id CHAR(16) NOT NULL,
    str VARCHAR(4096) NOT NULL,
    status BOOLEAN,
    address_id INT,
    o_id CHAR(16) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (address_id) REFERENCES message_address(id)
);

CREATE INDEX message_address_idx ON message (address_id);
CREATE INDEX message_created_idx ON message (created);
CREATE INDEX message_int_id_idx ON message (int_id);

-- Прочие лог-события
CREATE TABLE IF NOT EXISTS log (
    created TIMESTAMP NOT NULL,
    int_id CHAR(16) NOT NULL,
    str VARCHAR(4096) NOT NULL,
    address_id INT,
    o_id INT NOT NULL,
    FOREIGN KEY (address_id) REFERENCES message_address(id)
);

CREATE INDEX log_address_idx ON log (address_id);

-- Таблица для переменных
CREATE TABLE IF NOT EXISTS vars (
    n CHAR(16) NOT NULL,
    v CHAR(16) NOT NULL,
    PRIMARY KEY (n)
);

INSERT INTO vars (n, v) VALUES ('o_id', '$OIDSTART')
    ON DUPLICATE KEY UPDATE v = '$OIDSTART';
