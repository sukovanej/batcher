{-# LANGUAGE OverloadedStrings #-}

module Redis (createRedisConnection, assignQueueAndReturn) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Database.Redis as R

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
atomicSetGet :: BS.ByteString -> BS.ByteString -> Int -> R.Redis (Either R.Reply BS.ByteString)
atomicSetGet key value expire =
  R.sendRequest ["SET", key, value, "PX", integerToByteString expire, "GET"]

createAffinityKey :: BS.ByteString -> BS.ByteString
createAffinityKey = (<>) "queue_for:"

assignQueueAndReturn :: BS.ByteString -> BS.ByteString -> Int -> R.Connection -> IO (Either R.Reply (Maybe BS.ByteString))
assignQueueAndReturn queueName affinityValue expire connection = do
  BSC.putStrLn $ " [redis] Received key=" <> key <> ", value=" <> queueName
  R.runRedis connection $ do
      atomicSetGet key queueName expire
      R.get key
  where
    key = createAffinityKey affinityValue
