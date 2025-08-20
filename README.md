# MongoDB Sharded Cluster Docker Compose

This repository contains a Docker Compose setup for a **MongoDB sharded cluster** with two shards, a config replica set, `mongos` router, and `mongo-express` for web-based management.

## Architecture

```text
    +-----------------+
    |     mongos      |
    +-----------------+
    |             |
+----------+   +----------+
| Shard 1  |   | Shard 2  |
+----------+   +----------+
| 3 replicas|   | 3 replicas|
+----------+   +----------+
    |             |
+-----------------+
| Config Replica  |
| 3 members       |
+-----------------+
```

### Components

- **Config servers (`config1`, `config2`, `config3`)**  
  Store metadata for the sharded cluster. Deployed as a replica set.

- **Shards (`shard1a-c`, `shard2a-c`)**  
  Store the actual data. Each shard is a replica set with 3 members.

- **`mongos`**  
  Acts as the query router for the sharded cluster.

- **`mongo-express`**  
  Web interface to monitor the MongoDB cluster.

- **Init containers (`*_init`)**  
  Initialize replica sets and add shards to the `mongos` router.

---

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `MONGO_VERSION` | MongoDB Docker image version | `6.0.19` |
| `MONGO_EXPRESS_VERSION` | Mongo Express version | `latest` |
| `CONFIG_SVR_CPU_LIMIT` | CPU limit for config servers | `0.7` |
| `CONFIG_SVR_MEM_LIMIT` | Memory limit for config servers | `768M` |
| `SHARD_SVR_CPU_LIMIT` | CPU limit for shard servers | `1.0` |
| `SHARD_SVR_MEM_LIMIT` | Memory limit for shard servers | 2G` |
| `MONGOS_CPU_LIMIT` | CPU limit for mongos | `0.5` |
| `MONGOS_MEM_LIMIT` | Memory limit for mongos | `512M` |
| `MAX_LOG_FILE_SIZE` | Max size for container logs | `10m` |
| `MAX_LOG_FILE_COUNT` | Max number of log files | `3` |

---

## Services

### Config Servers

- `config1`, `config2`, `config3`  
  - Run `mongod` with `--configsvr` and `--replSet config`.  
  - Volumes: `/data/db` and `/data/configdb`.  
  - `config_init` initializes the config replica set.

### Shards

- **Shard 1**: `shard1a`, `shard1b`, `shard1c`  
  - Run `mongod` with `--shardsvr` and `--replSet shard1`.  
  - `shard1_init` initializes the replica set.

- **Shard 2**: `shard2a`, `shard2b`, `shard2c`  
  - Run `mongod` with `--shardsvr` and `--replSet shard2`.  
  - `shard2_init` initializes the replica set.

### Mongos Router

- `mongos`  
  - Routes queries to the correct shard.  
  - Depends on all replica sets being initialized.

- `mongos_init`  
  - Adds shard1 and shard2 to the mongos router.  
  - Runs any `.sh` scripts in `./init` directory.

### Mongo Express

- `mongo-express`  
  - Web interface to manage the cluster.  
  - Connects to `mongos`.  
  - Port: `8081`.

---

## Volumes

| Volume | Description |
|--------|-------------|
| `config1_db`, `config2_db`, `config3_db` | Config server data |
| `config1_configdb`, `config2_configdb`, `config3_configdb` | Config server metadata |
| `shard1a_db`, `shard1b_db`, `shard1c_db` | Shard1 data |
| `shard2a_db`, `shard2b_db`, `shard2c_db` | Shard2 data |

---

## Usage

1. Set environment variables in a `.env` file

    ```dotenv
    MONGO_VERSION=6.0.19
    MONGO_EXPRESS_VERSION=latest

    MAX_LOG_FILE_SIZE=20m
    MAX_LOG_FILE_COUNT=3

    CONFIG_SVR_CPU_LIMIT='0.5'
    CONFIG_SVR_MEM_LIMIT=1G
    SHARD_SVR_CPU_LIMIT='1'
    SHARD_SVR_MEM_LIMIT=1G
    MONGOS_CPU_LIMIT='1'
    MONGOS_MEM_LIMIT=1G
    ```

2. Start the cluster

    ```bash
    docker compose up -d
    ```

3. Access Mongo Express

    ```bash
    http://localhost:8081
    ```

4. Connect to the cluster via `mongosh`

    ```bash
    mongosh "mongodb://localhost:27017"
    ```

5. Stop the cluster

    ```bash
    docker compose down
    ```

6. Cleanup the cluster

    ```bash
    docker compose down -v 
    ```

## Notes

- Init containers (`*_init`) are executed only once to initialize replica sets and add shards.
- Healthchecks ensure that services start in the correct order.
- You can add custom shell scripts to `/init` to execute on the `mongos_init` container.
