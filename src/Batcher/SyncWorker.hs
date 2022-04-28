{-# LANGUAGE OverloadedStrings #-}

module Batcher.SyncWorker where

import Batcher.Constants (syncExchangeName)
import Batcher.Logger (HasLogger (..))
import Batcher.Queues (QueuesStorage, addQueue, removeQueue)
import Batcher.Worker (createWorkerQeueu)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Network.AMQP as AMQP

-- handle sync messages and update the queues storage
setupSyncWorker :: HasLogger l => l -> QueuesStorage -> AMQP.Connection -> IO ()
setupSyncWorker logger queuesStorage connection = do
  channel <- AMQP.openChannel connection
  queue <- createWorkerQeueu channel

  AMQP.bindQueue channel queue syncExchangeName ""

  logInfo logger "Worker ready"

  let handlerLogger = logNew logger "sync-worker"
  let handler = syncHandler logger queuesStorage
  AMQP.consumeMsgs channel queue AMQP.Ack handler

  return ()

data SyncAction = QeueuAdded BS.ByteString | QeueuRemoved BS.ByteString | Unknown BS.ByteString

syncHandler :: HasLogger l => l -> QueuesStorage -> (AMQP.Message, AMQP.Envelope) -> IO ()
syncHandler logger queuesStorage (msg, metadata) = do
  logInfo logger $ "Received " <> body
  triggerSyncAction logger queuesStorage $ parseSyncMessage body
  AMQP.ackEnv metadata
  where
    body = LBS.toStrict $ AMQP.msgBody msg

triggerSyncAction :: HasLogger l => l -> QueuesStorage -> SyncAction -> IO ()
triggerSyncAction logger queuesStorage (QeueuAdded queue) =
  removeQueue queuesStorage queue
    *> logInfo logger ("Queue added: " <> queue)
triggerSyncAction logger queuesStorage (QeueuRemoved queue) =
  addQueue queuesStorage queue
    *> logInfo logger ("Queue removed: " <> queue)
triggerSyncAction logger _ (Unknown queue) =
  logWarn logger $ "Unknwon message received: " <> queue

parseSyncMessage :: BS.ByteString -> SyncAction
parseSyncMessage message
  | "add " `BS.isPrefixOf` message = QeueuAdded $ BS.drop 4 message
  | "remove " `BS.isPrefixOf` message = QeueuRemoved $ BS.drop 7 message
  | otherwise = Unknown message
