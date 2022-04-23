{-# LANGUAGE OverloadedStrings #-}

module Batcher.ProcessingWorker () where

import Batcher.Logger (Logger (..))
import Batcher.Queues (QueuesStorage, addQueue, removeQueue)
import Batcher.Worker (createWorkerQeueu)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Data.Map as Map
import qualified Network.AMQP as AMQP
import qualified Network.AMQP.Types as AMQPT

setupProcessingWorker :: Logger l => l -> AMQP.Connection -> QueuesStorage -> IO AMQP.Channel
setupProcessingWorker logger connection queuesStorage = do
  channel <- AMQP.openChannel connection
  queue <- createWorkerQeueu channel

  AMQP.bindQueue channel queue queue ""

  logInfo logger "Worker ready"

  let handler = processingHandler $ logNew "processing-worker" logger
  AMQP.consumeMsgs channel queue AMQP.Ack handler

  return channel

processingHandler :: Logger l => l -> (AMQP.Message, AMQP.Envelope) -> IO ()
processingHandler logger (msg, metadata) = do
  let headers = AMQP.msgHeaders msg
  let replyTo = headers >>= getAffinityValueFromHeaders
  let affinityValue = headers >>= getAffinityValueFromHeaders

  logInfo logger $ "Received " <> body

  AMQP.ackEnv metadata
  where
    body = LBS.toStrict $ AMQP.msgBody msg

getAffinityValueFromHeaders :: AMQPT.FieldTable -> Maybe BS.ByteString
getAffinityValueFromHeaders = undefined

getReplyToFromHeaders :: AMQPT.FieldTable -> Maybe BS.ByteString
getReplyToFromHeaders = undefined
