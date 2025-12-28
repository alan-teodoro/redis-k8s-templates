# RDI Pipeline Examples

Pipeline configuration examples for different use cases.

---

## 📋 Overview

RDI pipelines are configured via:
1. **Redis Insight** (recommended - graphical interface)
2. **RDI CLI** (`redis-di` command)
3. **RDI API** (REST API)

---

## 🎯 Example 1: PostgreSQL → Redis (E-commerce)

### Use Case
Replicate product catalog from PostgreSQL to Redis for high-performance caching.

### Source Database (PostgreSQL)

```sql
-- Table: products
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2),
    stock_quantity INTEGER,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### RDI Pipeline Configuration

**config.yaml:**
```yaml
connections:
  target:
    type: redis
    host: redis-database.redis-enterprise.svc.cluster.local
    port: 12000
    password: ${REDIS_PASSWORD}
  
  source:
    type: postgresql
    host: postgres.database.svc.cluster.local
    port: 5432
    database: ecommerce
    user: rdi_user
    password: ${POSTGRES_PASSWORD}
    
    # CDC configuration
    plugin.name: pgoutput
    publication.name: rdi_publication
    slot.name: rdi_slot

# Snapshot configuration
snapshot:
  mode: initial
  threads: 4
```

**jobs/products.yaml:**
```yaml
source:
  server_name: postgres
  schema: public
  table: products

transform:
  - uses: add_field
    with:
      fields:
        - field: _key
          expression: concat(['product:', product_id])
        - field: _expiration
          expression: 3600  # 1 hour TTL

output:
  - uses: redis.write
    with:
      connection: target
      key:
        expression: _key
      data_type: json
      on_update: replace
```

### Result in Redis

```bash
# Key: product:123
# Type: JSON
# Value:
{
  "product_id": 123,
  "name": "Laptop Dell XPS 15",
  "description": "High-performance laptop",
  "price": 1299.99,
  "stock_quantity": 50,
  "category": "Electronics",
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:30:00Z"
}

# TTL: 3600 seconds
```

---

## 🎯 Example 2: MySQL → Redis (User Sessions)

### Use Case
Replicate user sessions from MySQL to Redis for ultra-fast access.

### Source Database (MySQL)

```sql
-- Table: user_sessions
CREATE TABLE user_sessions (
    session_id VARCHAR(64) PRIMARY KEY,
    user_id INT NOT NULL,
    username VARCHAR(100),
    email VARCHAR(255),
    login_time DATETIME,
    last_activity DATETIME,
    ip_address VARCHAR(45),
    user_agent TEXT,
    is_active BOOLEAN DEFAULT TRUE
);
```

### RDI Pipeline Configuration

**config.yaml:**
```yaml
connections:
  target:
    type: redis
    host: redis-database.redis-enterprise.svc.cluster.local
    port: 12000
  
  source:
    type: mysql
    host: mysql.database.svc.cluster.local
    port: 3306
    database: app_db
    user: rdi_user
    password: ${MYSQL_PASSWORD}
    
    # CDC configuration
    server.id: 12345
    binlog.format: ROW
```

**jobs/user_sessions.yaml:**
```yaml
source:
  server_name: mysql
  schema: app_db
  table: user_sessions

transform:
  - uses: add_field
    with:
      fields:
        - field: _key
          expression: concat(['session:', session_id])
        - field: _expiration
          expression: 7200  # 2 hours TTL
  
  # Filter: Only active sessions
  - uses: filter
    with:
      expression: is_active == true

output:
  - uses: redis.write
    with:
      connection: target
      key:
        expression: _key
      data_type: hash
      on_update: replace
      expire: _expiration
```

---

## 🚀 Deploy Pipeline

### Via Redis Insight

1. Open Redis Insight
2. Go to **RDI** section
3. Add connection: `https://rdi-api.example.com`
4. Create new pipeline
5. Configure source and target
6. Add jobs (transformations)
7. Deploy pipeline

### Via RDI CLI

```bash
# Set RDI host
export RDI_HOST=rdi-api.rdi.svc.cluster.local:8080

# Deploy pipeline
redis-di deploy --dir ./pipeline-config

# Start pipeline
redis-di start

# Check status
redis-di status

# Monitor
redis-di trace
```

---

## 🔗 Useful Links

- [RDI Pipelines](https://redis.io/docs/latest/integrate/redis-data-integration/data-pipelines/)
- [RDI Transformations](https://redis.io/docs/latest/integrate/redis-data-integration/data-pipelines/data-transformation/)
- [RDI in Redis Insight](https://redis.io/docs/latest/operate/redisinsight/rdi/)

