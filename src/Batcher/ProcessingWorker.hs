{-# LANGUAGE OverloadedStrings #-}

module Batcher.ProcessingWorker (setupProcessingWorker) where

import Batcher.Constants (processingExchangeName)
import Batcher.Logger (HasLogger (..))
import Batcher.ProcessingPublisher (publishProcessingResponse)
import Batcher.SyncPublisher (publishSync, publishSyncNewQueue)
import Batcher.Worker (createWorkerQeueu)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Data.Map as Map
import qualified Data.Text.Encoding as TE
import qualified Network.AMQP as AMQP
import qualified Network.AMQP.Types as AMQPT

setupProcessingWorker :: HasLogger l => l -> AMQP.Connection -> IO AMQP.Channel
setupProcessingWorker logger connection = do
  channel <- AMQP.openChannel connection
  queueName <- createWorkerQeueu channel

  AMQP.bindQueue channel queueName processingExchangeName queueName

  logInfo logger "Worker ready"

  let handlerLogger = logNew logger "handler"
  let handler = processingHandler handlerLogger channel
  AMQP.consumeMsgs channel queueName AMQP.Ack handler
  publishSyncNewQueue channel (TE.encodeUtf8 queueName)

  logInfo logger "Sync sent"

  return channel

processingHandler :: HasLogger l => l -> AMQP.Channel -> (AMQP.Message, AMQP.Envelope) -> IO ()
processingHandler logger channel (msg, metadata) = do
  let headers = AMQP.msgHeaders msg
  let replyTo = headers >>= getReplyToFromHeaders
  let affinityValue = headers >>= getAffinityValueFromHeaders

  let body = AMQP.msgBody msg

  logInfo logger $ "Received task for " <> show affinityValue <> ", replyTo=" <> show replyTo
  logDebug logger $ "Headers: " <> show headers

  case replyTo of
    Just replyTo -> do
      publishProcessingResponse channel replyTo (LBS.toStrict body)
      logDebug logger $ "Response sent to queue " <> replyTo
    Nothing -> logError logger "No reply-to header set"

  AMQP.ackEnv metadata
  where
    body = LBS.toStrict $ AMQP.msgBody msg

getAffinityValueFromHeaders :: AMQPT.FieldTable -> Maybe BS.ByteString
getAffinityValueFromHeaders (AMQPT.FieldTable m) = do
  value <- Map.lookup "affinity-value" m
  case value of
    AMQPT.FVString xs -> Just xs
    another -> Nothing

getReplyToFromHeaders :: AMQPT.FieldTable -> Maybe BS.ByteString
getReplyToFromHeaders (AMQPT.FieldTable m) = do
  value <- Map.lookup "reply-to" m
  case value of
    AMQPT.FVString xs -> Just xs
    another -> Nothing
