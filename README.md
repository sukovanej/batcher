# batcher

## Setup

Redis

```bash
docker run -d -p 6379:6379 --name batcher-redis redis
```

RabbitMQ

```bash
docker run -d -p 5672:5672 -p 15672:15672 --hostname batcher-rabbit --name batcher-rabbit rabbitmq:3-management
```
