{-# LANGUAGE OverloadedStrings #-}

module Batcher.Redis (createRedisConnection, assignQueueAndReturn) where

import Batcher.Logger (Logger (..))
import Batcher.Models (QueueName, AffinityValue, QueueAlreadyAssigned)
import Control.Applicative
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Data.Functor
import Data.Maybe
import qualified Database.Redis as R

type ExpireMiliseconds = Int

type RedisKey = BS.ByteString

type RedisValue = BS.ByteString

integerToByteString = BSC.pack . show

createRedisConnection :: IO R.Connection
createRedisConnection =
  R.checkedConnect
    R.defaultConnectInfo
      { R.connectDatabase = 1,
        R.connectHost = "localhost",
        R.connectPort = R.PortNumber 6379
      }

-- Set the <value> for the <key> only if it doesn exist and return it
atomicSetGet :: RedisKey -> RedisValue -> ExpireMiliseconds -> R.Redis (Either R.Reply (Maybe RedisValue))
atomicSetGet key value expire =
  R.sendRequest ["SET", key, value, "NX", "PX", integerToByteString expire]

createAffinityKey :: AffinityValue  -> RedisKey
createAffinityKey = (<>) "queue_for:"

assignQueueAndReturn :: Logger l => l -> QueueName -> AffinityValue -> ExpireMiliseconds -> R.Connection -> IO (Either R.Reply (QueueAlreadyAssigned, Maybe BS.ByteString))
assignQueueAndReturn logger queueName affinityValue expire connection = do
  logDebug logger $ "Received key=" <> key <> ", value=" <> queueName
  R.runRedis connection $ do
    getSetResponse <- atomicSetGet key queueName expire
    getResponse <- R.get key
    return $ liftA2 (,) (getSetResponse <&> isJust) getResponse
  where
    key = createAffinityKey affinityValue
