.PHONY: setup-local

setup-local:
	docker start batcher-redis
	docker start batcher-rabbit
