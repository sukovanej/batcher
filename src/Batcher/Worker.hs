{-# LANGUAGE OverloadedStrings #-}

module Batcher.Worker
  ( createAmqpConnection,
    createWorkerQeueu,
    createAmqpChannel,
    declareProcessingExchange,
    declareSyncExchange,
    createCallbackQueue,
    blockForAsyncResponse,
    closeAmqpChannel,
  )
where

import Batcher.Constants (processingExchangeName, syncExchangeName)
import Batcher.Models (QueueName, ResponseBody)
import Control.Concurrent (threadDelay)
import qualified Data.ByteString.Lazy as BSL
import Data.Functor
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Network.AMQP as AMQP

createAmqpConnection :: IO AMQP.Connection
createAmqpConnection = AMQP.openConnection "127.0.0.1" "/" "guest" "guest"

createAmqpChannel :: AMQP.Connection -> IO AMQP.Channel
createAmqpChannel = AMQP.openChannel

closeAmqpChannel :: AMQP.Channel -> IO ()
closeAmqpChannel = AMQP.closeChannel

createWorkerQeueu :: AMQP.Channel -> IO T.Text
createWorkerQeueu channel = do
  (queueName, _, _) <-
    AMQP.declareQueue
      channel
      AMQP.newQueue
        { AMQP.queueName = "",
          AMQP.queueAutoDelete = True,
          AMQP.queueDurable = False
        }

  return queueName

declareProcessingExchange :: AMQP.Channel -> IO ()
declareProcessingExchange channel = do
  let msg =
        AMQP.newExchange
          { AMQP.exchangeName = processingExchangeName,
            AMQP.exchangeType = "fanout",
            AMQP.exchangeDurable = False
          }

  void $ AMQP.declareExchange channel msg

declareProcessingResponseExchange :: AMQP.Channel -> IO ()
declareProcessingResponseExchange channel = do
  let msg =
        AMQP.newExchange
          { AMQP.exchangeName = processingExchangeName,
            AMQP.exchangeType = "direct",
            AMQP.exchangeDurable = False
          }

  void $ AMQP.declareExchange channel msg

declareSyncExchange :: AMQP.Channel -> IO ()
declareSyncExchange channel = do
  let msg =
        AMQP.newExchange
          { AMQP.exchangeName = syncExchangeName,
            AMQP.exchangeType = "fanout",
            AMQP.exchangeDurable = False
          }

  void $ AMQP.declareExchange channel msg

createCallbackQueue :: AMQP.Connection -> IO (QueueName, AMQP.Channel)
createCallbackQueue connection = do
  channel <- createAmqpChannel connection

  let queueOpts =
        AMQP.newQueue
          { AMQP.queueName = "",
            AMQP.queueExclusive = True
          }

  (queueName, _, _) <- AMQP.declareQueue channel queueOpts

  return (TE.encodeUtf8 queueName, channel)

type PollingMiliseconds = Int

blockForAsyncResponse :: PollingMiliseconds -> AMQP.Channel -> QueueName -> IO ResponseBody
blockForAsyncResponse pollingMiliseconds channel queue = do
  maybeResponse <- AMQP.getMsg channel AMQP.Ack (TE.decodeUtf8 queue)

  case maybeResponse of
    Just (message, env) ->
      threadDelay pollingMicroseconds
        $> BSL.toStrict (AMQP.msgBody message)
    Nothing -> blockForAsyncResponse pollingMiliseconds channel queue
  where
    pollingMicroseconds = pollingMiliseconds * 1000
