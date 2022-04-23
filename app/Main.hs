{-# LANGUAGE OverloadedStrings #-}

module Main where

import Batcher (emitMessage, receiveMessage)
import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (replicateM_)
import qualified Data.Text as T
import qualified Database.Redis as R
import Http (runHttpApplication)
import qualified Network.AMQP as AMQP
import Queues (newQueueStorage)
import Redis (createRedisConnection)
import Batcher.Worker (createAmqpConnection)

milisecond = 1000

second = 1000 * milisecond

exchange = "batcher-exchange"

main :: IO ()
main = mainApi

mainApi :: IO ()
mainApi = do
  redisConnection <- createRedisConnection
  amqpConnection <- createAmqpConnection
  queuesStorage <- newQueueStorage
  runHttpApplication queuesStorage redisConnection

mainWorker :: IO ()
mainWorker = do
  redisConnection <- createRedisConnection
  amqpConnection <- createAmqpConnection
  return ()
