module Batcher.Models
  ( AffinityValue,
    QueueName,
    QueueAlreadyAssigned,
    RequestBody,
    PublishProcessingFn,
    ResponseQueue,
    CreateCallbackQueueFn,
    ResponseBody,
  )
where

import qualified Data.ByteString as BS
import qualified Network.AMQP as AMQP

type QueueAlreadyAssigned = Bool

type AffinityValue = BS.ByteString

type QueueName = BS.ByteString

type RequestBody = BS.ByteString

type ResponseBody = BS.ByteString

type ResponseQueue = QueueName

type PublishProcessingFn = QueueName -> RequestBody -> ResponseQueue -> AffinityValue -> IO ()

type CreateCallbackQueueFn = IO (QueueName, AMQP.Channel)
