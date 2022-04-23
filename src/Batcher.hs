{-# LANGUAGE OverloadedStrings #-}

module Batcher (emitMessage, receiveMessage) where

import Control.Concurrent (threadDelay)
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.Text (Text)
import Network.AMQP
import Utils (bodyFor)

emitMessage :: Channel -> Text -> IO ()
emitMessage channel exchange = do
  publishMsg
    channel
    exchange
    ""
    ( newMsg
        { msgBody = "test",
          msgDeliveryMode = Just NonPersistent
        }
    )

  putStrLn " [publisher] Message sent"

receiveMessage :: Channel -> Text -> IO ()
receiveMessage channel exchange = do
  (queue, _, _) <-
    declareQueue
      channel
      newQueue
        { queueName = "",
          queueAutoDelete = True,
          queueDurable = False
        }

  bindQueue channel queue exchange ""

  BL.putStrLn " [consumer] Waiting for messages"
  consumeMsgs channel queue Ack deliveryHandler
  return ()

deliveryHandler :: (Message, Envelope) -> IO ()
deliveryHandler (msg, metadata) = do
  BL.putStrLn $ " [consumer] Received " <> body
  ackEnv metadata
  where
    body = msgBody msg
