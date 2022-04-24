{-# LANGUAGE OverloadedStrings #-}

module Main where

import Batcher.Http (runHttpApplication)
import Batcher.Logger (createDebugLogger)
import Batcher.ProcessingPublisher (publishProcessing)
import Batcher.ProcessingWorker (setupProcessingWorker)
import Batcher.Queues (newQueueStorage)
import Batcher.Redis (createRedisConnection)
import Batcher.Worker (createAmqpChannel, createAmqpConnection, createCallbackQueue, declareProcessingExchange, declareSyncExchange, closeAmqpChannel)
import Batcher.SyncWorker (setupSyncWorker)

main :: IO ()
main = mainApi

mainApi :: IO ()
mainApi = do
  -- common
  redisConnection <- createRedisConnection
  amqpConnection <- createAmqpConnection
  queuesStorage <- newQueueStorage

  initialChannel <- createAmqpChannel amqpConnection
  declareAllExchanges initialChannel
  closeAmqpChannel initialChannel

  -- api: sync worker setup
  let syncWorkerLogger = createDebugLogger "sync-worker"
  syncPublisherChannel <- createAmqpChannel amqpConnection
  setupSyncWorker syncWorkerLogger queuesStorage amqpConnection

  processingPublisherChannel <- createAmqpChannel amqpConnection

  -- processing-worker: setup
  let processingWorkerLogger = createDebugLogger "processing-worker"
  amqpConnection <- createAmqpConnection
  setupProcessingWorker processingWorkerLogger amqpConnection

  -- api: run
  let apiLogger = createDebugLogger "api"

  let publishProcessing' = publishProcessing processingPublisherChannel
  let createCallbackQueue' = createCallbackQueue amqpConnection

  runHttpApplication apiLogger queuesStorage redisConnection publishProcessing' createCallbackQueue'

mainWorker :: IO ()
mainWorker = do
  redisConnection <- createRedisConnection
  amqpConnection <- createAmqpConnection

  return ()

declareAllExchanges channel = do
  declareProcessingExchange channel
  declareSyncExchange channel
