# MongoDB Sharded Cluster with Docker Compose

A MongoDB sharded cluster deployment using Docker Compose, with automatic initialization and web-based administration.

## Architecture

This setup provides a complete MongoDB sharded cluster with the following components:

### Config Servers (3 nodes)

- `mongo-config-1`, `mongo-config-2`, `mongo-config-3`
- Replica set name: `config`
- Stores cluster metadata and configuration

### Shard 1 (3 nodes)

- `mongo-shard-1-a`, `mongo-shard-1-b`, `mongo-shard-1-c`
- Replica set name: `shard1`
- Stores a subset of the data

### Shard 2 (3 nodes)

- `mongo-shard-2-a`, `mongo-shard-2-b`, `mongo-shard-2-c`
- Replica set name: `shard2`
- Stores a subset of the data

### Router

- `mongos` - Query router that directs client requests to appropriate shards
- Accessible on port `27017` (configurable)

### Web UI

- `mongo-express` - Web-based MongoDB administration interface
- Accessible on port `8081` (configurable)
- No authentication required (configure for production use)

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 8GB of available RAM
- At least 20GB of available disk space

## Quick Start

1. **Clone the repository** (or create the files in your directory)

2. **Create environment configuration** (optional):

   ```bash
   cp .env.example .env
   ```

   Edit `.env` to customize settings if needed.

3. **Start the cluster**:

   ```bash
   docker compose up -d
   ```

4. **Monitor the startup process**:

   ```bash
   docker compose logs -f
   ```

   Wait for all initialization services to complete successfully.

5. **Access the cluster**:

   - MongoDB connection: <mongodb://localhost:27017>
   - Mongo Express UI: <http://localhost:8081>

6. **Verify cluster status**:

   ```bash
   docker compose exec mongos mongosh --eval "sh.status()"
   ```

## Configuration

All configurable options are available as environment variables. See `.env.example` for details.

### Key Configuration Options

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `MONGO_VERSION` | `latest` | MongoDB Docker image version |
| `MONGO_EXPRESS_VERSION` | `latest` | Mongo Express Docker image version |
| `MAX_LOG_FILE_SIZE` | `10m` | Maximum size of a single log file before rotation |
| `MAX_LOG_FILE_COUNT` | `3` | Maximum number of log files to keep |
| `MONGOS_BIND_ADDRESS` | `127.0.0.1` | Bind address for MongoDB router (use `0.0.0.0` for all interfaces) |
| `MONGOS_PORT` | `27017` | External port for MongoDB router |
| `MONGO_EXPRESS_BIND_ADDRESS` | `127.0.0.1` | Bind address for Mongo Express (use `0.0.0.0` for all interfaces) |
| `MONGO_EXPRESS_PORT` | `8081` | External port for web UI |
| `SHARD_SVR_CPU_LIMIT` | `1.0` | CPU limit per shard server |
| `SHARD_SVR_MEM_LIMIT` | `2G` | Memory limit per shard server |
| `CONFIG_SVR_CPU_LIMIT` | `0.7` | CPU limit per config server |
| `CONFIG_SVR_MEM_LIMIT` | `768M` | Memory limit per config server |
| `MONGOS_CPU_LIMIT` | `0.5` | CPU limit for mongos router |
| `MONGOS_MEM_LIMIT` | `512M` | Memory limit for mongos router |

### Security Considerations

#### ⚠️ IMPORTANT: Network Exposure Warning

**Do NOT set `MONGOS_BIND_ADDRESS` or `MONGO_EXPRESS_BIND_ADDRESS` to `0.0.0.0` in production environments** unless you have proper network security measures in place (firewall rules, VPN, etc.).

The default configuration binds services to `127.0.0.1` (localhost only) to prevent external access. Binding to `0.0.0.0` (all network interfaces) can expose your MongoDB cluster to security vulnerabilities, including:

- **MongoBleed CVE** ([SERVER-115508](https://jira.mongodb.org/browse/SERVER-115508)) - A critical vulnerability that can be exploited when MongoDB is exposed to untrusted networks
- Unauthorized access to your database
- Data breaches and data loss

**Recommended practices:**

- Keep bind addresses set to `127.0.0.1` for local development
- Use SSH tunneling or VPN for remote access
- If external access is required, implement proper authentication, network firewalls, and IP whitelisting
- Never expose MongoDB or Mongo Express directly to the internet without authentication and encryption

## Custom Initialization Scripts

You can add custom initialization scripts to the `init/` directory. The system will automatically execute:

- `.sh` files - Bash scripts (sourced with `.`)

Scripts are executed in the `mongos-init` container after shards are added to the cluster.

### Example: Create a sharded collection

Create `init/setup-database.sh`:

```bash
#!/bin/bash

mongosh --host mongos --eval '
  db = db.getSiblingDB("myapp");
  sh.enableSharding("myapp");
  db.createCollection("users");
  sh.shardCollection("myapp.users", { "_id": "hashed" });
  print("Database and collection created successfully");
'
```

## Management

### Start the cluster

```bash
docker compose up -d
```

### Stop the cluster

```bash
docker compose down
```

### Stop and remove all data

```bash
docker compose down -v
```

### View logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f mongos
```

### Connect with mongosh

```bash
docker compose exec mongos mongosh
```

### Check cluster status

```bash
docker compose exec mongos mongosh --eval "sh.status()"
```

### Check replica set status

```bash
# Config servers
docker compose exec mongo-config-1 mongosh --eval "rs.status()"

# Shard 1
docker compose exec mongo-shard-1-a mongosh --eval "rs.status()"

# Shard 2
docker compose exec mongo-shard-2-a mongosh --eval "rs.status()"
```

## Data Persistence

Data is persisted in Docker volumes:

- Config servers: `mongo_config_1_db`, `mongo_config_2_db`, `mongo_config_3_db`
- Shard 1: `mongo_shard_1_a_db`, `mongo_shard_1_b_db`, `mongo_shard_1_c_db`
- Shard 2: `mongo_shard_2_a_db`, `mongo_shard_2_b_db`, `mongo_shard_2_c_db`

Data persists across container restarts unless explicitly removed with `docker compose down -v`.

## Health Checks

Each MongoDB node includes a health check that verifies the MongoDB port is accepting connections. Services that depend on others will wait for health checks to pass before starting.

## Logging

Logs are configured with rotation to prevent disk space issues:

- Max log file size: `10m` (configurable)
- Max log files: `3` (configurable)
- Tagged with container name, image, and ID

## Troubleshooting

### Initialization services fail

- Check logs: `docker compose logs mongo-config-init mongo-shard-1-init mongo-shard-2-init mongos-init`
- Ensure all health checks pass before initialization runs
- Restart failed services: `docker compose restart <service-name>`

### Cannot connect to cluster

- Verify mongos is running: `docker compose ps mongos`
- Check mongos logs: `docker compose logs mongos`
- Ensure initialization completed: `docker compose ps mongos-init` (should show "exited (0)")

### Out of memory errors

- Increase Docker daemon memory allocation
- Reduce memory limits in `.env` file
- Consider using fewer replicas or shards

### Port conflicts

- Change `MONGOS_PORT` or `MONGO_EXPRESS_PORT` in `.env` file
- Check for other services using default ports

## License

MIT License

## Contributing

Feel free to submit issues and enhancement requests!
