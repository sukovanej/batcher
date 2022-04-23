{-# LANGUAGE OverloadedStrings #-}

module Queues (QueuesStorage, newQueueStorage, getRandomQueue, addQueue, removeQueue) where

import qualified Data.ByteString as BS
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Data.IORef

type QueueName = BS.ByteString

type QueuesStorage = IORef [QueueName]

newQueueStorage :: IO (IORef [QueueName])
newQueueStorage = newIORef []

getRandomQueue :: QueuesStorage -> IO QueueName
getRandomQueue _ = return "test"

addQueue :: QueuesStorage -> QueueName -> IO ()
addQueue ref queueName = atomicModifyIORef ref (\queues -> (filter (== queueName) queues, ()))

removeQueue :: QueuesStorage -> QueueName -> IO ()
removeQueue ref queueName = atomicModifyIORef ref (\queues -> (queueName : queues, ()))
