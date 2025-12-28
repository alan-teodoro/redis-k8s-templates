# Source Database Preparation for RDI CDC

Guide for preparing relational databases for Change Data Capture (CDC) with RDI.

---

## 📋 Supported Databases

- **Oracle** (11g, 12c, 19c, 21c)
- **PostgreSQL** (10+)
- **MySQL** (5.7, 8.0)
- **SQL Server** (2017, 2019, 2022)
- **MariaDB** (10.3+)
- **Google Cloud Spanner**

---

## 🔧 PostgreSQL

### Requirements

- PostgreSQL 10 or higher
- Logical replication enabled
- Replication slot created
- User with replication permissions

### Configuration

**1. Edit `postgresql.conf`:**

```ini
# Enable logical replication
wal_level = logical

# Set max replication slots (at least 1 per RDI pipeline)
max_replication_slots = 10

# Set max WAL senders (at least 1 per RDI pipeline)
max_wal_senders = 10

# Optional: Adjust WAL retention
wal_keep_size = 1GB
```

**2. Edit `pg_hba.conf`:**

```ini
# Allow replication connections from RDI
host    replication    rdi_user    10.0.0.0/8    md5
host    all            rdi_user    10.0.0.0/8    md5
```

**3. Restart PostgreSQL:**

```bash
sudo systemctl restart postgresql
```

**4. Create RDI user:**

```sql
-- Create user with replication privileges
CREATE USER rdi_user WITH REPLICATION PASSWORD 'secure_password';

-- Grant permissions on database
GRANT CONNECT ON DATABASE mydb TO rdi_user;

-- Grant permissions on schema
GRANT USAGE ON SCHEMA public TO rdi_user;

-- Grant SELECT on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rdi_user;

-- Grant SELECT on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO rdi_user;
```

**5. Create publication:**

```sql
-- Create publication for all tables
CREATE PUBLICATION rdi_publication FOR ALL TABLES;

-- Or create publication for specific tables
CREATE PUBLICATION rdi_publication FOR TABLE table1, table2, table3;
```

**6. Verify configuration:**

```sql
-- Check wal_level
SHOW wal_level;  -- Should be 'logical'

-- Check publication
SELECT * FROM pg_publication WHERE pubname = 'rdi_publication';

-- Check replication slots (after RDI starts)
SELECT * FROM pg_replication_slots;
```

---

## 🔧 MySQL

### Requirements

- MySQL 5.7 or 8.0
- Binary logging enabled
- ROW-based replication
- User with replication permissions

### Configuration

**1. Edit `my.cnf` or `my.ini`:**

```ini
[mysqld]
# Enable binary logging
log-bin = mysql-bin
server-id = 1

# Use ROW-based replication (required for CDC)
binlog_format = ROW

# Include all columns in binary log (required)
binlog_row_image = FULL

# Optional: Adjust binlog retention (in seconds)
binlog_expire_logs_seconds = 604800  # 7 days

# Optional: Adjust binlog size
max_binlog_size = 1G
```

**2. Restart MySQL:**

```bash
sudo systemctl restart mysql
```

**3. Create RDI user:**

```sql
-- Create user with replication privileges
CREATE USER 'rdi_user'@'%' IDENTIFIED BY 'secure_password';

-- Grant replication privileges
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'rdi_user'@'%';

-- Grant SELECT on databases to replicate
GRANT SELECT ON mydb.* TO 'rdi_user'@'%';

-- Apply changes
FLUSH PRIVILEGES;
```

**4. Verify configuration:**

```sql
-- Check binlog_format
SHOW VARIABLES LIKE 'binlog_format';  -- Should be 'ROW'

-- Check binlog_row_image
SHOW VARIABLES LIKE 'binlog_row_image';  -- Should be 'FULL'

-- Check binary logs
SHOW BINARY LOGS;

-- Check user privileges
SHOW GRANTS FOR 'rdi_user'@'%';
```

---

## 🔧 Oracle

### Requirements

- Oracle 11g, 12c, 19c, or 21c
- Archive log mode enabled
- Supplemental logging enabled
- User with LogMiner permissions

### Configuration

**1. Enable archive log mode:**

```sql
-- Connect as SYSDBA
sqlplus / as sysdba

-- Check if archive log is enabled
SELECT log_mode FROM v$database;

-- If not enabled, enable it
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

**2. Enable supplemental logging:**

```sql
-- Enable minimal supplemental logging (database level)
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- Enable supplemental logging for specific tables
ALTER TABLE schema.table1 ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE schema.table2 ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

**3. Create RDI user:**

```sql
-- Create user
CREATE USER rdi_user IDENTIFIED BY secure_password;

-- Grant permissions
GRANT CREATE SESSION TO rdi_user;
GRANT SELECT ANY TABLE TO rdi_user;
GRANT SELECT_CATALOG_ROLE TO rdi_user;
GRANT EXECUTE_CATALOG_ROLE TO rdi_user;

-- Grant LogMiner permissions
GRANT SELECT ON V_$DATABASE TO rdi_user;
GRANT SELECT ON V_$LOGFILE TO rdi_user;
GRANT SELECT ON V_$LOG TO rdi_user;
GRANT SELECT ON V_$ARCHIVED_LOG TO rdi_user;
GRANT SELECT ON V_$LOGMNR_CONTENTS TO rdi_user;
GRANT EXECUTE ON DBMS_LOGMNR TO rdi_user;
GRANT EXECUTE ON DBMS_LOGMNR_D TO rdi_user;
```

**4. Verify configuration:**

```sql
-- Check archive log mode
SELECT log_mode FROM v$database;  -- Should be 'ARCHIVELOG'

-- Check supplemental logging
SELECT supplemental_log_data_min FROM v$database;  -- Should be 'YES'

-- Check table supplemental logging
SELECT table_name, log_group_name FROM dba_log_groups WHERE owner = 'SCHEMA';
```

---

## ✅ Verification Checklist

### PostgreSQL
- [ ] `wal_level = logical`
- [ ] `max_replication_slots >= 1`
- [ ] `max_wal_senders >= 1`
- [ ] RDI user created with REPLICATION privilege
- [ ] Publication created
- [ ] pg_hba.conf allows replication connections

### MySQL
- [ ] `binlog_format = ROW`
- [ ] `binlog_row_image = FULL`
- [ ] Binary logging enabled
- [ ] RDI user created with REPLICATION SLAVE privilege
- [ ] RDI user has SELECT on target databases

### Oracle
- [ ] Archive log mode enabled
- [ ] Supplemental logging enabled (database level)
- [ ] Supplemental logging enabled (table level)
- [ ] RDI user created with LogMiner permissions
- [ ] RDI user has SELECT on target tables

