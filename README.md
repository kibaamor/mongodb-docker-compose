# MongoDB with Docker Compose

Two MongoDB deployment modes are provided:

| Mode | Compose file | Use when |
| ---- | ------------ | -------- |
| Single instance | `docker-compose.single.yaml` | You need a simple local MongoDB server with Mongo Express |
| Cluster | `docker-compose.cluster.yaml` | You need sharding behavior, replica sets, router behavior, or multi-node initialization testing |

Both modes support persistent data volumes, health checks, resource limits, log rotation, configurable bind addresses, explicit WiredTiger cache sizing, and Mongo Express. Cluster mode also includes automatic replica set and shard initialization plus optional shell scripts from `init/`.

## Quick Start

### Prerequisites

- Docker
- Docker Compose v2 (`docker compose`)

### 1. Choose a Mode

Symlink the compose file you want to use:

```bash
# Single instance mode
ln -sf docker-compose.single.yaml docker-compose.yaml

# Cluster mode
ln -sf docker-compose.cluster.yaml docker-compose.yaml
```

Notes:

- `docker-compose.yaml` is gitignored, so each checkout can choose its own mode.
- Do not run both modes at the same time from the same directory unless you use distinct Compose project names with `docker compose -p <project-name>`.

### 2. Configure

The defaults work for local development. To customize them:

```bash
cp .env.example .env
```

Then edit `.env` as needed. By default, MongoDB and Mongo Express bind to `127.0.0.1`.

### 3. Start

```bash
docker compose up -d
```

### 4. Verify

Single instance mode:

```bash
docker compose exec mongo mongosh --eval "db.runCommand({ ping: 1 })"
```

Cluster mode:

```bash
docker compose logs -f mongos-init
docker compose exec mongos mongosh --eval "sh.status()"
```

Mongo Express is available at <http://localhost:8081> with the default configuration.

### 5. Stop

```bash
docker compose down
```

Remove persisted data as well:

```bash
docker compose down -v
```

## Deployment Details

### Single Instance Mode

Single instance mode runs:

- `mongo` on port `27017` by default
- `mongo-express` on port `8081` by default
- one named data volume: `mongo_data`

Mongo Express connects to `mongodb://mongo:27017/`.

### Cluster Mode

Cluster mode runs a sharded MongoDB deployment:

- 3 config server nodes in replica set `config`
- 2 shard replica sets, `shard1` and `shard2`, with 3 nodes each
- `mongos`, which routes client connections on port `27017` by default
- `mongo-config-init`, `mongo-shard-1-init`, and `mongo-shard-2-init`, which initialize replica sets after nodes are healthy
- `mongos-init`, which adds both shards after `mongos` is healthy
- `mongo-express`, which starts after cluster initialization succeeds

Notes:

- The default cluster resource limits add up to about 8.6 CPU cores and 15 GB of memory before initialization jobs and Mongo Express overhead.
- Use single instance mode when you do not need sharding.

Default published ports:

| Service | Default port | Variable |
| ------- | ------------ | -------- |
| `mongos` | `27017` | `MONGOS_PORT` |
| `mongo-express` | `8081` | `MONGO_EXPRESS_PORT` |

Cluster data volumes:

- `mongo_config_1_db`
- `mongo_config_1_configdb`
- `mongo_config_2_db`
- `mongo_config_2_configdb`
- `mongo_config_3_db`
- `mongo_config_3_configdb`
- `mongo_shard_1_a_db`
- `mongo_shard_1_b_db`
- `mongo_shard_1_c_db`
- `mongo_shard_2_a_db`
- `mongo_shard_2_b_db`
- `mongo_shard_2_c_db`

Notes:

- Only `*.sh` files in `init/` are executed.
- Scripts run inside the `mongos-init` container after both shards are added, are sourced into the same bash process, and do not need the executable bit.
- A failing script aborts `mongos-init`; because the service uses `restart: on-failure`, it retries.
- Single instance mode does not run scripts from `init/`.

## Configuration

All settings are configured through `.env`. See `.env.example` for comments and examples.

### MongoDB

| Variable | Default | Scope | Description |
| -------- | ------- | ----- | ----------- |
| `MONGO_VERSION` | `latest` | Both | MongoDB image version |
| `MONGO_BIND_ADDRESS` | `127.0.0.1` | Single | Network interface for the single MongoDB instance |
| `MONGO_PORT` | `27017` | Single | Single MongoDB host port |
| `MONGO_CPU_LIMIT` | `1.0` | Single | Single MongoDB CPU limit |
| `MONGO_MEM_LIMIT` | `1G` | Single | Single MongoDB memory limit |
| `MONGO_WT_CACHE_SIZE_GB` | `0.5` | Single | Single MongoDB WiredTiger cache size in GB |
| `MONGOS_BIND_ADDRESS` | `127.0.0.1` | Cluster | Network interface for the `mongos` router |
| `MONGOS_PORT` | `27017` | Cluster | `mongos` host port |
| `CONFIG_SVR_CPU_LIMIT` | `0.7` | Cluster | CPU limit for each config server |
| `CONFIG_SVR_MEM_LIMIT` | `768M` | Cluster | Memory limit for each config server |
| `CONFIG_SVR_WT_CACHE_SIZE_GB` | `0.25` | Cluster | WiredTiger cache size in GB for each config server |
| `SHARD_SVR_CPU_LIMIT` | `1.0` | Cluster | CPU limit for each shard server |
| `SHARD_SVR_MEM_LIMIT` | `2G` | Cluster | Memory limit for each shard server |
| `SHARD_SVR_WT_CACHE_SIZE_GB` | `1.0` | Cluster | WiredTiger cache size in GB for each shard server |
| `MONGOS_CPU_LIMIT` | `0.5` | Cluster | CPU limit for the `mongos` router |
| `MONGOS_MEM_LIMIT` | `512M` | Cluster | Memory limit for the `mongos` router |

Notes:

- `mongod` sizes its default WiredTiger cache from host memory, which can be much larger than a container memory limit.
- These compose files pass `--wiredTigerCacheSizeGB` to every `mongod`; when you change a `*_MEM_LIMIT` value, keep the matching `*_WT_CACHE_SIZE_GB` at roughly half of it.
- `mongos` holds no data files and needs no cache setting.

### Mongo Express

| Variable | Default | Scope | Description |
| -------- | ------- | ----- | ----------- |
| `MONGO_EXPRESS_VERSION` | `latest` | Both | Mongo Express image version |
| `MONGO_EXPRESS_BIND_ADDRESS` | `127.0.0.1` | Both | Network interface Mongo Express binds to |
| `MONGO_EXPRESS_PORT` | `8081` | Both | Web UI port |

### Logging

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `MAX_LOG_FILE_SIZE` | `10m` | Maximum size of a single log file |
| `MAX_LOG_FILE_COUNT` | `3` | Number of log files to keep |

## Networking

Both compose files publish container ports to the host with configurable bind addresses.

- `MONGO_BIND_ADDRESS` controls where the single MongoDB instance listens.
- `MONGOS_BIND_ADDRESS` controls where the cluster `mongos` router listens.
- `MONGO_EXPRESS_BIND_ADDRESS` controls where Mongo Express listens.
- If a service binds to `127.0.0.1`, connect with `localhost` or `127.0.0.1`.
- If a service binds to `0.0.0.0`, connect with `127.0.0.1` locally or the host IP remotely; do not use `0.0.0.0` as the client address.

Notes:

- Keep MongoDB and Mongo Express bound to `127.0.0.1` unless you intentionally expose them through a trusted network boundary.
- This project does not enable MongoDB authentication by default.

## Compatibility

Tested end-to-end in both modes. Mongo Express has also been verified.

| MongoDB version | Cluster mode | Single instance mode |
| --------------- | ------------ | -------------------- |
| 8.2 | Supported | Supported |
| 8.0 | Supported | Supported |
| 7.0 | Supported | Supported |
| 6.0 | Supported | Supported |
| 5.0 | Supported | Supported |
| 4.4 | Not supported | Supported |
| 4.2 | Not supported | Supported |
| 4.0 | Not supported | Supported |

Notes:

- Cluster mode is not supported on 4.x because the official MongoDB 4.x images do not bundle `mongosh`, which the initialization services require.
- The `mongod` nodes can start on 4.x, but automated replica set and sharding initialization cannot run.
- On 4.x in single instance mode, replace `mongosh` with `mongo` in the commands in this README; the 4.x images bundle the legacy `mongo` shell instead of `mongosh`.

Set the image version with `MONGO_VERSION` in `.env`, for example `7.0` or `8.0`.

## Persistence

Notes:

- Docker named volumes survive container restarts and `docker compose down`.
- Use `docker compose down -v` only when you want to remove persisted MongoDB data.
- Single instance mode stores data in `mongo_data`.
- Cluster mode stores config server and shard data in the named volumes listed in [Cluster Mode](#cluster-mode).

## Common Commands

These commands assume the default bind address and ports.

### Cluster Mode

```bash
# Connect through mongos
docker compose exec mongos mongosh

# View cluster status and shards
docker compose exec mongos mongosh --eval "sh.status()"
docker compose exec mongos mongosh --eval "db.adminCommand({ listShards: 1 })"

# Test writes and reads through mongos
docker compose exec mongos mongosh --eval 'db.getSiblingDB("demo").items.insertOne({ message: "Hello MongoDB Cluster" })'
docker compose exec mongos mongosh --eval 'db.getSiblingDB("demo").items.findOne({ message: "Hello MongoDB Cluster" })'

# Check a shard replica set
docker compose exec mongo-shard-1-a mongosh --eval "rs.status()"
```

### Single Instance Mode

```bash
docker compose exec mongo mongosh
docker compose exec mongo mongosh --eval "db.runCommand({ ping: 1 })"
```

### Monitoring

```bash
docker compose ps
docker compose logs -f
docker compose logs -f mongos
docker compose logs -f mongo
docker stats
```

## Operations

### Validate Compose Files

```bash
docker compose -f docker-compose.single.yaml config
docker compose -f docker-compose.cluster.yaml config
```

### Troubleshoot Startup

Check initialization and service state:

```bash
docker compose ps
docker compose logs mongo-config-init mongo-shard-1-init mongo-shard-2-init mongos-init
```

Check MongoDB connectivity:

```bash
# Cluster mode
docker compose logs mongos
docker compose exec mongos mongosh --eval "db.runCommand({ ping: 1 })"

# Single instance mode
docker compose logs mongo
docker compose exec mongo mongosh --eval "db.runCommand({ ping: 1 })"
```

Check Mongo Express:

```bash
docker compose logs mongo-express
docker compose ps mongo-express
```

If cluster nodes fail to start under load, increase `CONFIG_SVR_MEM_LIMIT`, `SHARD_SVR_MEM_LIMIT`, `CONFIG_SVR_CPU_LIMIT`, or `SHARD_SVR_CPU_LIMIT` in `.env`.

## License

[MIT License](LICENSE)
