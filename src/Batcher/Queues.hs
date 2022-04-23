{-# LANGUAGE OverloadedStrings #-}

module Batcher.Queues (QueuesStorage, QueueName, newQueueStorage, getRandomQueue, addQueue, removeQueue) where

import Batcher.Models (QueueName)
import qualified Data.ByteString as BS
import Data.IORef
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)

type QueuesStorage = IORef [QueueName]

newQueueStorage :: IO (IORef [QueueName])
newQueueStorage = newIORef []

getRandomQueue :: QueuesStorage -> IO QueueName
getRandomQueue _ = return "test"

addQueue :: QueuesStorage -> QueueName -> IO ()
addQueue ref queueName = atomicModifyIORef ref (\queues -> (filter (== queueName) queues, ()))

removeQueue :: QueuesStorage -> QueueName -> IO ()
removeQueue ref queueName = atomicModifyIORef ref (\queues -> (queueName : queues, ()))
