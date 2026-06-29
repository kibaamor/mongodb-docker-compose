# MongoDB with Docker Compose

Two MongoDB deployment modes using Docker Compose:

- **Cluster mode** (`docker-compose.cluster.yaml`): sharded MongoDB cluster with config servers, two replica-set shards, automatic initialization, and Mongo Express
- **Single instance** (`docker-compose.single.yaml`): standalone MongoDB instance with Mongo Express web interface

## Features

- ✅ Sharded MongoDB cluster with config servers and two shards — cluster mode
- ✅ Single MongoDB instance with Mongo Express — standalone mode
- ✅ Automatic replica set and shard initialization — cluster mode
- ✅ Optional custom initialization scripts — cluster mode
- ✅ Mongo Express web management interface
- ✅ Data persistence
- ✅ Health checks
- ✅ Resource limit configuration
- ✅ Log rotation configuration
- ✅ Configurable MongoDB bind addresses via `MONGO_BIND_ADDRESS` and `MONGOS_BIND_ADDRESS`
- ✅ Configurable Mongo Express bind address via `MONGO_EXPRESS_BIND_ADDRESS`

## Quick Start

### Prerequisites

- Docker
- Docker Compose v2 (`docker compose`)

### Choose Deployment Mode

Use single instance mode when you want a simple local MongoDB server. Use cluster mode when you need to test sharding behavior, shard routing, and multi-node initialization.

| Need | Recommended Mode |
| ---- | ---------------- |
| Local development, simple database testing, or minimal resource usage | Single instance |
| Sharding behavior, router behavior, replica sets, or cluster initialization testing | Cluster |

Select the compose file that matches your needs, then symlink it to `docker-compose.yaml` so you can use `docker compose` without `-f` flags:

```bash
# For cluster mode (recommended if you need sharding)
ln -sf docker-compose.cluster.yaml docker-compose.yaml

# For single instance mode (simpler, no clustering overhead)
ln -sf docker-compose.single.yaml docker-compose.yaml
```

> Note:
> `docker-compose.yaml` is gitignored, so each checkout can choose its own mode without changing tracked files.

### Configure

Copy the environment variable file if you want to customize the defaults:

```bash
cp .env.example .env
```

Then edit `.env` as needed.

> Tip:
> By default, MongoDB and Mongo Express bind to `127.0.0.1`. If you change bind addresses, see [Networking](#networking) before updating connection strings or browser URLs.

### Start

```bash
docker compose up -d
```

### Verify Cluster Mode

```bash
# Check shard initialization status
docker compose logs -f mongos-init

# Check cluster state through mongos
docker compose exec mongos mongosh --eval "sh.status()"
```

> Note:
> On first startup, the config server and shard initialization services create the replica sets after their MongoDB nodes are healthy. The `mongos-init` service adds both shards after `mongos` is healthy. If the cluster already exists, the initialization commands detect that state and skip duplicate setup. Mongo Express starts after cluster initialization succeeds.

### Verify Single Instance Mode

```bash
# Check if MongoDB is running
docker compose logs -f mongo

# Ping MongoDB
docker compose exec mongo mongosh --eval "db.runCommand({ ping: 1 })"
```

### Open Mongo Express

With the default configuration, open <http://localhost:8081>.

> Tip:
> If you customize `MONGO_EXPRESS_BIND_ADDRESS` or `MONGO_EXPRESS_PORT`, open Mongo Express at the reachable host address and configured port. See [Networking](#networking) for bind address behavior.

### Stop

```bash
docker compose down
```

### Stop and Remove Data

```bash
docker compose down -v
```

## Common Commands

The commands below assume the default MongoDB bind addresses and ports:

- `MONGOS_BIND_ADDRESS=127.0.0.1`
- `MONGOS_PORT=27017` for cluster mode
- `MONGO_BIND_ADDRESS=127.0.0.1`
- `MONGO_PORT=27017` for single instance mode

> Tip:
> If you customize those values, replace connection strings, browser URLs, and host ports with reachable MongoDB address and port values. See [Networking](#networking) for bind address behavior.

### Cluster Mode

```bash
# Connect through mongos
docker compose exec mongos mongosh

# View cluster status
docker compose exec mongos mongosh --eval "sh.status()"

# View cluster shards
docker compose exec mongos mongosh --eval "db.adminCommand({ listShards: 1 })"

# Insert a sample document through mongos
docker compose exec mongos mongosh --eval 'db.getSiblingDB("demo").items.insertOne({ message: "Hello MongoDB Cluster" })'

# Read the sample document through mongos
docker compose exec mongos mongosh --eval 'db.getSiblingDB("demo").items.findOne({ message: "Hello MongoDB Cluster" })'

# Check a shard replica set status
docker compose exec mongo-shard-1-a mongosh --eval "rs.status()"
```

### Single Instance Mode

```bash
# Connect to MongoDB
docker compose exec mongo mongosh

# Ping MongoDB
docker compose exec mongo mongosh --eval "db.runCommand({ ping: 1 })"
```

### Monitoring

```bash
# View all service status
docker compose ps

# View service logs
docker compose logs -f

# View specific service logs (cluster mode)
docker compose logs -f mongos

# View specific service logs (single instance mode)
docker compose logs -f mongo

# View resource usage
docker stats
```

## Architecture

### Deployment Modes

| Mode | Compose File | Description |
| ---- | ------------ | ----------- |
| Cluster | `docker-compose.cluster.yaml` | Sharded MongoDB cluster with automatic initialization |
| Single | `docker-compose.single.yaml` | Standalone MongoDB instance with Mongo Express |

### Cluster Mode

Cluster mode runs a sharded MongoDB deployment with config servers, two shards, a `mongos` router, initialization jobs, and Mongo Express:

- 3 config server nodes in replica set `config`
- 2 shard replica sets, each with 3 MongoDB nodes
- 1 `mongos` router for client connections
- 1 Mongo Express web interface connected to `mongodb://mongos:27017/`

Default published ports:

| Service | Default Port | Environment Variable |
| ------- | ------------ | -------------------- |
| `mongos` | `27017` | `MONGOS_PORT` |
| `mongo-express` | `8081` | `MONGO_EXPRESS_PORT` |

Initialization services:

- `mongo-config-init`
- `mongo-shard-1-init`
- `mongo-shard-2-init`
- `mongos-init`

Custom initialization scripts in `init/` are run by the `mongos-init` service after both shards are added to the cluster. Single instance mode does not run scripts from `init/`.

### Single Instance Mode

Single instance mode runs one MongoDB service named `mongo` on port `27017` by default. The port is configurable via `MONGO_PORT`.

Mongo Express runs as `mongo-express` and connects to `mongodb://mongo:27017/`.

Default published ports:

| Service | Default Port | Environment Variable |
| ------- | ------------ | -------------------- |
| `mongo` | `27017` | `MONGO_PORT` |
| `mongo-express` | `8081` | `MONGO_EXPRESS_PORT` |

### Networking

Both compose files publish container ports to the host with configurable bind addresses. The defaults bind services to `127.0.0.1`, which keeps MongoDB and Mongo Express accessible only from the local machine.

`MONGO_BIND_ADDRESS` controls where the single MongoDB instance listens on the host. `MONGOS_BIND_ADDRESS` controls where the cluster `mongos` router listens on the host. `MONGO_EXPRESS_BIND_ADDRESS` controls where the Mongo Express web UI listens on the host.

When a service binds to `127.0.0.1`, use `localhost` or `127.0.0.1` locally. When a service binds to a LAN address, use that reachable host address. If a service binds to `0.0.0.0`, do not use `0.0.0.0` as the client address; use `127.0.0.1` locally or the host IP remotely.

## Configuration

All configurations can be customized through the `.env` file. Refer to `.env.example` for the full list.

### MongoDB Configuration

| Environment Variable | Default Value | Scope | Description |
| --------- | ----- | ----- | ------ |
| `MONGO_VERSION` | `latest` | Both | MongoDB image version |
| `MONGO_BIND_ADDRESS` | `127.0.0.1` | Single | Network interface for the single MongoDB instance |
| `MONGO_PORT` | `27017` | Single | Port for the single MongoDB instance |
| `MONGO_CPU_LIMIT` | `1.0` | Single | CPU limit for the single MongoDB instance |
| `MONGO_MEM_LIMIT` | `1G` | Single | Memory limit for the single MongoDB instance |
| `MONGOS_BIND_ADDRESS` | `127.0.0.1` | Cluster | Network interface for the `mongos` router |
| `MONGOS_PORT` | `27017` | Cluster | Port for the `mongos` router |
| `CONFIG_SVR_CPU_LIMIT` | `0.7` | Cluster | CPU limit for each config server |
| `CONFIG_SVR_MEM_LIMIT` | `768M` | Cluster | Memory limit for each config server |
| `SHARD_SVR_CPU_LIMIT` | `1.0` | Cluster | CPU limit for each shard server |
| `SHARD_SVR_MEM_LIMIT` | `2G` | Cluster | Memory limit for each shard server |
| `MONGOS_CPU_LIMIT` | `0.5` | Cluster | CPU limit for the `mongos` router |
| `MONGOS_MEM_LIMIT` | `512M` | Cluster | Memory limit for the `mongos` router |

### Mongo Express Configuration

| Environment Variable | Default Value | Scope | Description |
| --------- | ----- | ----- | ------ |
| `MONGO_EXPRESS_VERSION` | `latest` | Both | Mongo Express image version |
| `MONGO_EXPRESS_BIND_ADDRESS` | `127.0.0.1` | Both | Network interface Mongo Express binds to |
| `MONGO_EXPRESS_PORT` | `8081` | Both | Web interface access port |

### Logging Configuration

| Environment Variable | Default Value | Scope | Description |
| --------- | ----- | ----- | ------ |
| `MAX_LOG_FILE_SIZE` | `10m` | Both | Maximum size of a single log file |
| `MAX_LOG_FILE_COUNT` | `3` | Both | Number of log files to keep |

## Data Persistence

### Cluster Mode

Cluster mode uses Docker named volumes for config server and shard data:

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

### Single Instance Mode

Single MongoDB instance uses one data volume:

- `mongo_data`

> Warning:
> Docker named volumes are preserved across container restarts. Use `docker compose down -v` only when you want to remove the persisted data volumes.

## Failover

Cluster mode uses MongoDB replica sets for config servers and shard servers:

- Each config server replica set has 3 members
- Each shard replica set has 3 members
- If a primary becomes unavailable, MongoDB replica set election can promote an eligible secondary
- Health checks verify that MongoDB port `27017` is accepting connections

## Production Notes

These compose files are intended for local development, testing, and controlled environments.

- Keep MongoDB and Mongo Express bind addresses set to `127.0.0.1` for local-only access.
- Avoid exposing MongoDB or Mongo Express to an untrusted network without access controls.
- If you bind MongoDB or Mongo Express to a LAN interface or `0.0.0.0`, restrict access with host firewall rules or a trusted network boundary.
- Pin `MONGO_VERSION` and `MONGO_EXPRESS_VERSION` instead of using `latest` when you need repeatable deployments.
- This project does not enable MongoDB authentication by default.
- Use `docker compose down -v` only when you want to remove named volumes.

## Troubleshooting

### Cluster Initialization Failed

```bash
# Check initialization logs
docker compose logs mongo-config-init mongo-shard-1-init mongo-shard-2-init mongos-init

# Check if all services are healthy
docker compose ps

# Restart cluster shard initialization
docker compose restart mongos-init
```

### Cannot Connect to MongoDB

```bash
# Cluster mode: check router logs
docker compose logs mongos

# Cluster mode: ping through mongos
docker compose exec mongos mongosh --eval "db.runCommand({ ping: 1 })"

# Single instance mode: check logs
docker compose logs mongo

# Single instance mode: ping MongoDB
docker compose exec mongo mongosh --eval "db.runCommand({ ping: 1 })"
```

> Tip:
> If you changed `MONGO_BIND_ADDRESS` or `MONGOS_BIND_ADDRESS`, use a reachable MongoDB address in external clients. See [Networking](#networking) for details.

### Cannot Connect to Mongo Express

```bash
# Check Mongo Express status
docker compose logs mongo-express

# Check Mongo Express service
docker compose ps mongo-express
```

> Tip:
> If you changed `MONGO_EXPRESS_BIND_ADDRESS` or `MONGO_EXPRESS_PORT`, confirm the reachable host address and configured port. See [Networking](#networking) for details.

### Node Cannot Start (Cluster Mode)

```bash
# Check router logs
docker compose logs mongos

# Check a shard node log
docker compose logs mongo-shard-1-a
```

If resource limits are too low, edit `.env` and increase `SHARD_SVR_MEM_LIMIT`, `CONFIG_SVR_MEM_LIMIT`, `SHARD_SVR_CPU_LIMIT`, or `CONFIG_SVR_CPU_LIMIT`.

## License

[MIT License](LICENSE)

## Contributing

Issues and pull requests are welcome.

Before submitting a change, verify the affected mode:

```bash
# Validate cluster compose configuration
docker compose -f docker-compose.cluster.yaml config

# Validate single instance compose configuration
docker compose -f docker-compose.single.yaml config
```

For README changes, check that documented service names, ports, and environment variables still match the compose files and `.env.example`.
