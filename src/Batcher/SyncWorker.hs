{-# LANGUAGE OverloadedStrings #-}

module Batcher.SyncWorker where

import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Network.AMQP as AMQP
import Queues (QueuesStorage, addQueue, removeQueue)

syncExchange = "sync-pub-sub"

-- handle sync messages and update the queues storage
setupSyncWorker :: QueuesStorage -> IO ()
setupSyncWorker queuesStorage = do
  connection <- AMQP.openConnection "127.0.0.1" "/" "guest" "guest"
  channel <- AMQP.openChannel connection

  AMQP.declareExchange
    channel
    AMQP.newExchange
      { AMQP.exchangeName = syncExchange,
        AMQP.exchangeType = "fanout",
        AMQP.exchangeDurable = False
      }

  (queue, _, _) <-
    AMQP.declareQueue
      channel
      AMQP.newQueue
        { AMQP.queueName = "",
          AMQP.queueAutoDelete = True,
          AMQP.queueDurable = False
        }

  AMQP.bindQueue channel queue syncExchange ""

  putStrLn " [sync-worker] Worker ready"

  let handler = syncHandler queuesStorage
  AMQP.consumeMsgs channel queue AMQP.Ack handler

  return ()

data SyncAction = QeueuAdded BS.ByteString | QeueuRemoved BS.ByteString | Unknown BS.ByteString

syncHandler :: QueuesStorage -> (AMQP.Message, AMQP.Envelope) -> IO ()
syncHandler queuesStorage (msg, metadata) = do
  BS.putStrLn $ " [sync-worker] Received " <> body
  triggerSyncAction queuesStorage $ parseSyncMessage body
  AMQP.ackEnv metadata
  where
    body = LBS.toStrict $ AMQP.msgBody msg

triggerSyncAction :: QueuesStorage -> SyncAction -> IO ()
triggerSyncAction queuesStorage (QeueuAdded queue) =
  removeQueue queuesStorage queue *> logAdded queue
triggerSyncAction queuesStorage (QeueuRemoved queue) =
  addQueue queuesStorage queue *> logRemoved queue
triggerSyncAction _ (Unknown queue) =
  logUnknown queue

logWithQueueMessage message queue = putStrLn $ message <> BS.unpack queue

logRemoved = logWithQueueMessage " [sync-worker] Queue removed: "

logAdded = logWithQueueMessage " [sync-worker] New queue added: "

logUnknown = logWithQueueMessage " [sync-worker] Unknwon message received"

parseSyncMessage :: BS.ByteString -> SyncAction
parseSyncMessage message
  | "add " `BS.isPrefixOf` message = QeueuAdded $ BS.drop 4 message
  | "remove " `BS.isPrefixOf` message = QeueuRemoved $ BS.drop 7 message
  | otherwise = Unknown message
