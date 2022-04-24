{-# LANGUAGE OverloadedStrings #-}

module Batcher.ProcessingPublisher (publishProcessing, publishProcessingResponse) where

import Batcher.Constants (processingExchangeName, processingResponseExchangeName)
import Batcher.Models (AffinityValue, QueueName, RequestBody, ResponseBody, ResponseQueue)
import qualified Data.ByteString.Lazy as BSL
import Data.Functor
import qualified Data.Map as Map
import qualified Data.Text.Encoding as TE
import qualified Network.AMQP as AMQP
import qualified Network.AMQP.Types as AMQPT

publishProcessing :: AMQP.Channel -> QueueName -> RequestBody -> ResponseQueue -> AffinityValue -> IO ()
publishProcessing channel queueName body responseQueueName affinityValue = do
  let msgHeaders = AMQPT.FieldTable $ Map.fromList [("affinity-value", AMQPT.FVString affinityValue), ("reply-to", AMQPT.FVString responseQueueName)]

  let msg =
        AMQP.newMsg
          { AMQP.msgBody = BSL.fromStrict body,
            AMQP.msgDeliveryMode = Just AMQP.NonPersistent,
            AMQP.msgReplyTo = Just $ TE.decodeUtf8 responseQueueName,
            AMQP.msgHeaders = Just msgHeaders
          }

  void $ AMQP.publishMsg channel processingExchangeName (TE.decodeUtf8 queueName) msg

publishProcessingResponse :: AMQP.Channel -> QueueName -> ResponseBody -> IO ()
publishProcessingResponse channel queueName body = do
  let msg =
        AMQP.newMsg
          { AMQP.msgBody = BSL.fromStrict body,
            AMQP.msgDeliveryMode = Just AMQP.NonPersistent
          }

  void $ AMQP.publishMsg channel "" (TE.decodeUtf8 queueName) msg
