{-# LANGUAGE OverloadedStrings #-}

module Batcher.ProcessingWorker () where

import Batcher.Worker (createWorkerQeueu)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Data.Map as Map
import qualified Network.AMQP as AMQP
import qualified Network.AMQP.Types as AMQPT
import Queues (QueuesStorage, addQueue, removeQueue)

setupProcessingWorker :: AMQP.Connection -> QueuesStorage -> IO AMQP.Channel
setupProcessingWorker connection queuesStorage = do
  channel <- AMQP.openChannel connection
  queue <- createWorkerQeueu channel

  AMQP.bindQueue channel queue queue ""

  putStrLn " [processing-worker] Worker ready"

  AMQP.consumeMsgs channel queue AMQP.Ack processingHandler

  return channel

processingHandler :: (AMQP.Message, AMQP.Envelope) -> IO ()
processingHandler (msg, metadata) = do
  let headers = AMQP.msgHeaders msg
  let replyTo = headers >>= getAffinityValueFromHeaders
  let affinityValue = headers >>= getAffinityValueFromHeaders

  BS.putStrLn $ " [sync] Received " <> body

  AMQP.ackEnv metadata
  where
    body = LBS.toStrict $ AMQP.msgBody msg

getAffinityValueFromHeaders :: AMQPT.FieldTable -> Maybe BS.ByteString
getAffinityValueFromHeaders = undefined

getReplyToFromHeaders :: AMQPT.FieldTable -> Maybe BS.ByteString
getReplyToFromHeaders = undefined
