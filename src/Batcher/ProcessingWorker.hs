{-# LANGUAGE OverloadedStrings #-}

module Batcher.ProcessingWorker () where

import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Network.AMQP as AMQP
import Queues (QueuesStorage, addQueue, removeQueue)

-- handle sync messages and update the queues storage
setupProcessingWorker :: QueuesStorage -> IO ()
setupProcessingWorker queuesStorage = do
  connection <- AMQP.openConnection "127.0.0.1" "/" "guest" "guest"
  channel <- AMQP.openChannel connection

  (queue, _, _) <-
    AMQP.declareQueue
      channel
      AMQP.newQueue
        { AMQP.queueName = "",
          AMQP.queueAutoDelete = True,
          AMQP.queueDurable = False
        }

  AMQP.bindQueue channel queue "" queue

  putStrLn " [processing-worker] Worker ready"

  AMQP.consumeMsgs channel queue AMQP.Ack processingHandler

  return ()

processingHandler :: (AMQP.Message, AMQP.Envelope) -> IO ()
processingHandler (msg, metadata) = do
  BS.putStrLn $ " [sync] Received " <> body
  AMQP.ackEnv metadata
  where
    body = LBS.toStrict $ AMQP.msgBody msg
