{-# LANGUAGE OverloadedStrings #-}

module Main where

import Batcher.Logger (createDebugLogger)
import Batcher.Redis (createRedisConnection)
import Batcher.Worker (createAmqpConnection)
import Batcher.Http (runHttpApplication)
import Batcher.Queues (newQueueStorage)

main :: IO ()
main = mainApi

mainApi :: IO ()
mainApi = do
  redisConnection <- createRedisConnection
  amqpConnection <- createAmqpConnection
  queuesStorage <- newQueueStorage
  let logger = createDebugLogger "api"
  runHttpApplication logger queuesStorage redisConnection amqpConnection

mainWorker :: IO ()
mainWorker = do
  redisConnection <- createRedisConnection
  amqpConnection <- createAmqpConnection
  return ()
