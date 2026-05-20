/**
 * @Author: Your name
 * @Date:   2026-05-14 14:58:40
 * @Last Modified by:   Your name
 * @Last Modified time: 2026-05-20 07:44:00
 */
-- ============================================================
--  TransitFlow PostgreSQL Schema
--  Seed data is loaded separately by: python skeleton/seed_postgres.py
--
--  TWO ROLES:
--    1. Relational  → dual-network transit data you design below
--    2. Vector      → policy documents for RAG (provided — do not modify)
-- ============================================================

-- ============================================================
--  STUDENT TASK — Design and create your relational tables here
--
--  Start from the mock data in train-mock-data/:
--    metro_stations.json, national_rail_stations.json
--    metro_schedules.json, national_rail_schedules.json
--    national_rail_seat_layouts.json
--    registered_users.json
--    bookings.json, metro_travel_history.json
--    payments.json, feedback.json
--
--  Think about:
--    - What tables do you need?
--    - What columns and data types?
--    - Which fields are primary keys? Which are foreign keys?
--    - What constraints make sense?
--
--  Apply your schema with:
--    docker-compose down -v && docker-compose up -d
-- ============================================================




-- ============================================================
--  VECTOR SCHEMA  (RAG / Help Desk) — do not modify
-- ============================================================

-- ============================================================
--  RELATIONAL SCHEMA
--  Based only on the JSON files in train-mock-data/.
-- ============================================================

CREATE TABLE IF NOT EXISTS registered_users (
    user_id       VARCHAR(10) PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    phone         VARCHAR(30),
    date_of_birth DATE,
    registered_at TIMESTAMPTZ,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS password (
    user_id            VARCHAR(10) PRIMARY KEY REFERENCES registered_users(user_id),
    password_hash      TEXT NOT NULL,
    salt               TEXT,
    secret_question    TEXT,
    secret_answer      TEXT
);

CREATE TABLE IF NOT EXISTS metro_stations (
    station_id                           VARCHAR(10) PRIMARY KEY,
    name                                 VARCHAR(100) NOT NULL,
    is_interchange_metro                 BOOLEAN NOT NULL DEFAULT FALSE,
    is_interchange_national_rail         BOOLEAN NOT NULL DEFAULT FALSE,
    interchange_national_rail_station_id VARCHAR(10)
);

CREATE TABLE IF NOT EXISTS metro_station_lines (
    station_id VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    line       VARCHAR(20) NOT NULL,
    PRIMARY KEY (station_id, line)
);

CREATE TABLE IF NOT EXISTS metro_station_interchange_lines (
    station_id VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    line       VARCHAR(20) NOT NULL,
    PRIMARY KEY (station_id, line)
);

CREATE TABLE IF NOT EXISTS metro_adjacent_stations (
    station_id          VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    adjacent_station_id VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    line                VARCHAR(20) NOT NULL,
    travel_time_min     INT NOT NULL,
    PRIMARY KEY (station_id, adjacent_station_id, line)
);

CREATE TABLE IF NOT EXISTS national_rail_stations (
    station_id                   VARCHAR(10) PRIMARY KEY,
    name                         VARCHAR(100) NOT NULL,
    is_interchange_metro         BOOLEAN NOT NULL DEFAULT FALSE,
    is_interchange_national_rail BOOLEAN NOT NULL DEFAULT FALSE,
    interchange_metro_station_id VARCHAR(10) REFERENCES metro_stations(station_id)
);

ALTER TABLE metro_stations
    ADD CONSTRAINT metro_stations_interchange_national_rail_fk
    FOREIGN KEY (interchange_national_rail_station_id)
    REFERENCES national_rail_stations(station_id)
    DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE IF NOT EXISTS national_rail_station_lines (
    station_id VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    line       VARCHAR(20) NOT NULL,
    PRIMARY KEY (station_id, line)
);

CREATE TABLE IF NOT EXISTS national_rail_interchange_lines (
    station_id VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    line       VARCHAR(20) NOT NULL,
    PRIMARY KEY (station_id, line)
);

CREATE TABLE IF NOT EXISTS national_rail_adjacent_stations (
    station_id          VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    adjacent_station_id VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    line                VARCHAR(20) NOT NULL,
    travel_time_min     INT NOT NULL,
    PRIMARY KEY (station_id, adjacent_station_id, line)
);

CREATE TABLE IF NOT EXISTS ticket_types (
    ticket_type  VARCHAR(30) PRIMARY KEY,
    display_name VARCHAR(100) NOT NULL,
    description  TEXT
);

CREATE TABLE IF NOT EXISTS ticket_type_available_on (
    ticket_type  VARCHAR(30) NOT NULL REFERENCES ticket_types(ticket_type),
    network_type VARCHAR(30) NOT NULL CHECK (network_type IN ('metro', 'national_rail')),
    PRIMARY KEY (ticket_type, network_type)
);

CREATE TABLE IF NOT EXISTS ticket_type_metro_rules (
    ticket_type         VARCHAR(30) PRIMARY KEY REFERENCES ticket_types(ticket_type),
    pricing_model      VARCHAR(50),
    formula            TEXT,
    example            TEXT,
    fare_class         VARCHAR(20),
    price_usd          NUMERIC(8,2),
    seat_assignment    BOOLEAN,
    unlimited_journeys BOOLEAN,
    validity           TEXT,
    advance_purchase   BOOLEAN,
    changes_allowed    BOOLEAN,
    transferable       BOOLEAN,
    refundable         BOOLEAN,
    refund_rule        VARCHAR(50),
    notes              TEXT
);

CREATE TABLE IF NOT EXISTS ticket_type_metro_valid_lines (
    ticket_type VARCHAR(30) NOT NULL REFERENCES ticket_type_metro_rules(ticket_type),
    line        VARCHAR(20) NOT NULL,
    PRIMARY KEY (ticket_type, line)
);

CREATE TABLE IF NOT EXISTS ticket_type_national_rail_rules (
    ticket_type               VARCHAR(30) PRIMARY KEY REFERENCES ticket_types(ticket_type),
    pricing_model             VARCHAR(50),
    formula                   TEXT,
    seat_assignment           BOOLEAN,
    validity                  TEXT,
    outbound_validity         TEXT,
    return_validity           TEXT,
    advance_purchase          BOOLEAN,
    advance_purchase_max_days INT,
    changes_allowed           BOOLEAN,
    change_fee_usd            NUMERIC(8,2),
    change_deadline           TEXT,
    refundable                BOOLEAN,
    refund_rule               VARCHAR(100),
    notes                     TEXT
);

CREATE TABLE IF NOT EXISTS ticket_type_national_rail_fare_classes (
    ticket_type VARCHAR(30) NOT NULL REFERENCES ticket_type_national_rail_rules(ticket_type),
    fare_class  VARCHAR(20) NOT NULL,
    PRIMARY KEY (ticket_type, fare_class)
);

CREATE TABLE IF NOT EXISTS metro_schedules (
    schedule_id            VARCHAR(20) PRIMARY KEY,
    line                   VARCHAR(20) NOT NULL,
    direction              VARCHAR(50),
    origin_station_id      VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    destination_station_id VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    first_train_time       TIME,
    last_train_time        TIME,
    frequency_min          INT,
    base_fare_usd          NUMERIC(8,2),
    per_stop_rate_usd      NUMERIC(8,2)
);

CREATE TABLE IF NOT EXISTS metro_schedule_operates_on (
    schedule_id VARCHAR(20) NOT NULL REFERENCES metro_schedules(schedule_id),
    day_name    VARCHAR(10) NOT NULL,
    PRIMARY KEY (schedule_id, day_name)
);

CREATE TABLE IF NOT EXISTS metro_schedule_stops (
    schedule_id                 VARCHAR(20) NOT NULL REFERENCES metro_schedules(schedule_id),
    station_id                  VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    stop_sequence               INT NOT NULL,
    PRIMARY KEY (schedule_id, station_id),
    UNIQUE (schedule_id, stop_sequence)
);

CREATE TABLE IF NOT EXISTS metro_schedule_travel_time_from_origin (
    schedule_id                 VARCHAR(20) NOT NULL REFERENCES metro_schedules(schedule_id),
    station_id                  VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    travel_time_from_origin_min INT NOT NULL,
    PRIMARY KEY (schedule_id, station_id)
);

CREATE TABLE IF NOT EXISTS national_rail_schedules (
    schedule_id            VARCHAR(20) PRIMARY KEY,
    line                   VARCHAR(20) NOT NULL,
    service_type           VARCHAR(20) NOT NULL,
    direction              VARCHAR(50),
    origin_station_id      VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    destination_station_id VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    first_train_time       TIME,
    last_train_time        TIME,
    frequency_min          INT
);

CREATE TABLE IF NOT EXISTS national_rail_schedule_operates_on (
    schedule_id VARCHAR(20) NOT NULL REFERENCES national_rail_schedules(schedule_id),
    day_name    VARCHAR(10) NOT NULL,
    PRIMARY KEY (schedule_id, day_name)
);

CREATE TABLE IF NOT EXISTS national_rail_schedule_stops (
    schedule_id                 VARCHAR(20) NOT NULL REFERENCES national_rail_schedules(schedule_id),
    station_id                  VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    stop_sequence               INT NOT NULL,
    is_passed_through           BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (schedule_id, station_id),
    UNIQUE (schedule_id, stop_sequence)
);

CREATE TABLE IF NOT EXISTS national_rail_schedule_travel_time_from_origin (
    schedule_id                 VARCHAR(20) NOT NULL REFERENCES national_rail_schedules(schedule_id),
    station_id                  VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    travel_time_from_origin_min INT NOT NULL,
    PRIMARY KEY (schedule_id, station_id)
);

CREATE TABLE IF NOT EXISTS national_rail_schedule_fare_classes (
    schedule_id       VARCHAR(20) NOT NULL REFERENCES national_rail_schedules(schedule_id),
    fare_class        VARCHAR(20) NOT NULL,
    base_fare_usd     NUMERIC(8,2) NOT NULL,
    per_stop_rate_usd NUMERIC(8,2) NOT NULL,
    PRIMARY KEY (schedule_id, fare_class)
);

CREATE TABLE IF NOT EXISTS national_rail_seat_layouts (
    layout_id   VARCHAR(20) PRIMARY KEY,
    schedule_id VARCHAR(20) NOT NULL REFERENCES national_rail_schedules(schedule_id)
);

CREATE TABLE IF NOT EXISTS national_rail_coaches (
    layout_id   VARCHAR(20) NOT NULL REFERENCES national_rail_seat_layouts(layout_id),
    schedule_id VARCHAR(20) NOT NULL REFERENCES national_rail_schedules(schedule_id),
    coach       VARCHAR(10) NOT NULL,
    fare_class  VARCHAR(20) NOT NULL,
    PRIMARY KEY (layout_id, coach),
    UNIQUE (schedule_id, coach)
);

CREATE TABLE IF NOT EXISTS national_rail_seats (
    layout_id   VARCHAR(20) NOT NULL,
    schedule_id VARCHAR(20) NOT NULL,
    coach       VARCHAR(10) NOT NULL,
    seat_id     VARCHAR(10) NOT NULL,
    seat_row    INT,
    seat_column VARCHAR(5),
    PRIMARY KEY (layout_id, coach, seat_id),
    UNIQUE (schedule_id, coach, seat_id),
    FOREIGN KEY (layout_id, coach)
        REFERENCES national_rail_coaches(layout_id, coach),
    FOREIGN KEY (schedule_id, coach)
        REFERENCES national_rail_coaches(schedule_id, coach)
);

CREATE TABLE IF NOT EXISTS national_rail_bookings (
    booking_id             VARCHAR(20) PRIMARY KEY,
    user_id                VARCHAR(10) NOT NULL REFERENCES registered_users(user_id),
    schedule_id            VARCHAR(20) NOT NULL REFERENCES national_rail_schedules(schedule_id),
    origin_station_id      VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    destination_station_id VARCHAR(10) NOT NULL REFERENCES national_rail_stations(station_id),
    travel_date            DATE NOT NULL,
    departure_time         TIME,
    ticket_type            VARCHAR(30) NOT NULL REFERENCES ticket_types(ticket_type),
    fare_class             VARCHAR(20),
    coach                  VARCHAR(10),
    seat_id                VARCHAR(10),
    stops_travelled        INT,
    amount_usd             NUMERIC(8,2),
    status                 VARCHAR(30),
    booked_at              TIMESTAMPTZ,
    travelled_at           TIMESTAMPTZ,
    FOREIGN KEY (schedule_id, coach, seat_id)
        REFERENCES national_rail_seats(schedule_id, coach, seat_id)
);

CREATE TABLE IF NOT EXISTS metro_bookings (
    trip_id                VARCHAR(20) PRIMARY KEY,
    user_id                VARCHAR(10) NOT NULL REFERENCES registered_users(user_id),
    schedule_id            VARCHAR(20) NOT NULL REFERENCES metro_schedules(schedule_id),
    origin_station_id      VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    destination_station_id VARCHAR(10) NOT NULL REFERENCES metro_stations(station_id),
    ticket_type            VARCHAR(30) NOT NULL REFERENCES ticket_types(ticket_type),
    day_pass_ref           VARCHAR(20) REFERENCES metro_bookings(trip_id),
    travel_date            DATE NOT NULL,
    purchased_at           TIMESTAMPTZ,
    travelled_at           TIMESTAMPTZ,
    stops_travelled        INT,
    amount_usd             NUMERIC(8,2),
    status                 VARCHAR(30)
);

-- booking_id stores the original JSON reference:
--   BKxxx -> national_rail_bookings.booking_id
--   MTxxx -> metro_bookings.trip_id
CREATE TABLE IF NOT EXISTS payments (
    payment_id VARCHAR(20) PRIMARY KEY,
    booking_id VARCHAR(20) NOT NULL,
    amount_usd NUMERIC(8,2) NOT NULL,
    method     VARCHAR(30),
    status     VARCHAR(30),
    paid_at    TIMESTAMPTZ,
    CHECK (booking_id LIKE 'BK%' OR booking_id LIKE 'MT%')
);

-- booking_id stores the original JSON reference:
--   BKxxx -> national_rail_bookings.booking_id
--   MTxxx -> metro_bookings.trip_id
CREATE TABLE IF NOT EXISTS feedback (
    feedback_id  VARCHAR(20) PRIMARY KEY,
    booking_id   VARCHAR(20) NOT NULL,
    user_id      VARCHAR(10) NOT NULL REFERENCES registered_users(user_id),
    rating       INT CHECK (rating BETWEEN 1 AND 5),
    comment      TEXT,
    submitted_at TIMESTAMPTZ,
    CHECK (booking_id LIKE 'BK%' OR booking_id LIKE 'MT%')
);

CREATE TABLE IF NOT EXISTS refund_policy (
    policy_id           VARCHAR(20) PRIMARY KEY,
    label               TEXT NOT NULL,
    return_ticket_notes TEXT,
    no_show_policy      TEXT,
    notes               TEXT,
    exclusions          TEXT
);

CREATE TABLE IF NOT EXISTS refund_policy_applies_to (
    policy_id    VARCHAR(20) PRIMARY KEY REFERENCES refund_policy(policy_id),
    network_type VARCHAR(30),
    service_type VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS refund_policy_applies_to_ticket_types (
    policy_id   VARCHAR(20) NOT NULL REFERENCES refund_policy_applies_to(policy_id),
    ticket_type VARCHAR(30) NOT NULL REFERENCES ticket_types(ticket_type),
    PRIMARY KEY (policy_id, ticket_type)
);

CREATE TABLE IF NOT EXISTS refund_cancellation_windows (
    window_id                  VARCHAR(30) PRIMARY KEY,
    policy_id                  VARCHAR(20) NOT NULL REFERENCES refund_policy(policy_id),
    label                      TEXT,
    condition                  TEXT,
    status_condition           TEXT,
    hours_before_departure_min INT,
    hours_before_departure_max INT,
    refund_percent             INT,
    admin_fee_usd              NUMERIC(8,2)
);

CREATE TABLE IF NOT EXISTS refund_compensation_rules (
    rule_id      VARCHAR(30) PRIMARY KEY,
    policy_id    VARCHAR(20) NOT NULL REFERENCES refund_policy(policy_id),
    condition    TEXT,
    compensation TEXT,
    how_to_claim TEXT
);

CREATE TABLE IF NOT EXISTS booking_rules (
    version       VARCHAR(20) PRIMARY KEY,
    last_updated  DATE,
    general_rules JSONB
);

CREATE TABLE IF NOT EXISTS booking_rule_network_sections (
    version         VARCHAR(20) NOT NULL REFERENCES booking_rules(version),
    network_type    VARCHAR(30) NOT NULL CHECK (network_type IN ('metro', 'national_rail')),
    advance_booking JSONB,
    seat_selection  JSONB,
    ticket_changes  JSONB,
    child_fares     JSONB,
    group_fares     JSONB,
    payment         JSONB,
    booking_confirmation JSONB,
    PRIMARY KEY (version, network_type)
);

CREATE TABLE IF NOT EXISTS travel_policies (
    version       VARCHAR(20) PRIMARY KEY,
    last_updated  DATE
);

CREATE TABLE IF NOT EXISTS travel_policy_network_sections (
    version              VARCHAR(20) NOT NULL REFERENCES travel_policies(version),
    network_type         VARCHAR(30) NOT NULL CHECK (network_type IN ('metro', 'national_rail')),
    bicycles             JSONB,
    luggage              JSONB,
    pets                 JSONB,
    food_and_drink       JSONB,
    priority_seating     JSONB,
    prohibited_items     JSONB,
    smoking_and_vaping   TEXT,
    noise                TEXT,
    quiet_zones          JSONB,
    accessibility        JSONB,
    conduct              TEXT,
    PRIMARY KEY (version, network_type)
);

CREATE INDEX IF NOT EXISTS idx_registered_users_email
    ON registered_users(email);

CREATE INDEX IF NOT EXISTS idx_nr_bookings_user_date
    ON national_rail_bookings(user_id, travel_date);

CREATE INDEX IF NOT EXISTS idx_nr_bookings_schedule_date
    ON national_rail_bookings(schedule_id, travel_date);

CREATE INDEX IF NOT EXISTS idx_metro_bookings_user_date
    ON metro_bookings(user_id, travel_date);

CREATE INDEX IF NOT EXISTS idx_payments_booking_id
    ON payments(booking_id);

CREATE INDEX IF NOT EXISTS idx_feedback_booking_id
    ON feedback(booking_id);

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS policy_documents (
    id          SERIAL       PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    category    VARCHAR(50)  NOT NULL,  -- 'refund', 'booking', 'conduct'
    content     TEXT         NOT NULL,
    -- 768-dim  → Ollama nomic-embed-text (default)
    -- 3072-dim → Gemini gemini-embedding-001
    -- If you switch LLM_PROVIDER to gemini, change to vector(3072) and reset the database.
    embedding   vector(768),
    source_file VARCHAR(200),
    created_at  TIMESTAMPTZ  DEFAULT NOW()
);

-- Index for fast cosine similarity search
CREATE INDEX IF NOT EXISTS ON policy_documents USING hnsw (embedding vector_cosine_ops);