{-# LANGUAGE OverloadedStrings #-}

module Batcher.Redis (createRedisConnection, assignQueueAndReturn, RedisConnection, HasRedisConnection(..)) where

import Batcher.Logger (HasLogger (..))
import Batcher.Models (AffinityValue, QueueAlreadyAssigned, QueueName)
import Control.Applicative
import Data.Bifunctor
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import Data.Functor
import Data.Maybe
import qualified Database.Redis as R

type ExpireMiliseconds = Int

type RedisKey = BS.ByteString

type RedisValue = BS.ByteString

type RedisConnection = R.Connection

integerToByteString = BSC.pack . show

class HasRedisConnection a where
  redisConnection :: a -> RedisConnection

createRedisConnection :: IO RedisConnection
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

createAffinityKey :: AffinityValue -> RedisKey
createAffinityKey = (<>) "queue_for:"

assignQueueAndReturn :: (HasLogger env, HasRedisConnection env) => env -> QueueName -> AffinityValue -> ExpireMiliseconds -> IO (Either R.Reply (QueueAlreadyAssigned, Maybe BS.ByteString))
assignQueueAndReturn env queueName affinityValue expire = do
  logDebug env $ "Request key=" <> key <> ", value=" <> queueName
  response <- R.runRedis (redisConnection env) $ do
    getSetResponse <- atomicSetGet key queueName expire
    getResponse <- R.get key
    return $ liftA2 (,) getSetResponse getResponse

  case response of
    Right (getSetResponse, getResponse) -> logDebug env $ "getSetResponse: " <> show getSetResponse
    Left reply -> logError env $ "Response: " <> show reply

  return $ response <&> first isNothing
  where
    key = createAffinityKey affinityValue
