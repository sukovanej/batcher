{-# LANGUAGE OverloadedStrings #-}

module Batcher.SyncPublisher (publishSync, publishSyncNewQueue, publishSyncRemoveQueue) where

import Batcher.Constants (syncExchangeName)
import Batcher.Models (QueueName, ResponseQueue)
import qualified Data.ByteString.Lazy as BSL
import Data.Functor
import qualified Data.Text.Encoding as TE
import qualified Network.AMQP as AMQP

publishSync :: AMQP.Channel -> ResponseQueue -> IO ()
publishSync channel responseQueueName = do
  let msg =
        AMQP.newMsg
          { AMQP.msgBody = "sync",
            AMQP.msgDeliveryMode = Just AMQP.NonPersistent,
            AMQP.msgReplyTo = Just $ TE.decodeUtf8 responseQueueName
          }

  void $ AMQP.publishMsg channel syncExchangeName "" msg

-- Publish that new queue is processing
publishSyncNewQueue :: AMQP.Channel -> QueueName -> IO ()
publishSyncNewQueue channel queueName = do
  let msg =
        AMQP.newMsg
          { AMQP.msgBody = "add " <> BSL.fromStrict queueName,
            AMQP.msgDeliveryMode = Just AMQP.NonPersistent
          }

  void $ AMQP.publishMsg channel syncExchangeName "" msg

-- Publish that worker stopped
publishSyncRemoveQueue :: AMQP.Channel -> QueueName -> IO ()
publishSyncRemoveQueue channel queueName = do
  let msg =
        AMQP.newMsg
          { AMQP.msgBody = "remove " <> BSL.fromStrict queueName,
            AMQP.msgDeliveryMode = Just AMQP.NonPersistent
          }

  void $ AMQP.publishMsg channel syncExchangeName "" msg
