{-# LANGUAGE OverloadedStrings #-}

module Batcher.Redis (createRedisConnection, assignQueueAndReturn, RedisConnection) where

import Batcher.Logger (Logger (..))
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

assignQueueAndReturn :: Logger l => l -> QueueName -> AffinityValue -> ExpireMiliseconds -> RedisConnection -> IO (Either R.Reply (QueueAlreadyAssigned, Maybe BS.ByteString))
assignQueueAndReturn logger queueName affinityValue expire connection = do
  logDebug logger $ "Request key=" <> key <> ", value=" <> queueName
  response <- R.runRedis connection $ do
    getSetResponse <- atomicSetGet key queueName expire
    getResponse <- R.get key
    return $ liftA2 (,) getSetResponse getResponse

  case response of
    Right (getSetResponse, getResponse) -> logDebug logger $ "getSetResponse: " <> show getSetResponse
    Left reply -> logError logger $ "Response: " <> show reply

  return $ response <&> first isNothing
  where
    key = createAffinityKey affinityValue
