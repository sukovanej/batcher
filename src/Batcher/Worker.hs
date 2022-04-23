{-# LANGUAGE OverloadedStrings #-}

module Batcher.Worker (createAmqpConnection, createWorkerQeueu) where

import qualified Data.Text as T
import qualified Network.AMQP as AMQP

createAmqpConnection :: IO AMQP.Connection
createAmqpConnection = AMQP.openConnection "127.0.0.1" "/" "guest" "guest"

createWorkerQeueu :: AMQP.Channel -> IO T.Text
createWorkerQeueu channel = do
  (queue, _, _) <-
    AMQP.declareQueue
      channel
      AMQP.newQueue
        { AMQP.queueName = "",
          AMQP.queueAutoDelete = True,
          AMQP.queueDurable = False
        }

  return queue
