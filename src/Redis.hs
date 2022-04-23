{-# LANGUAGE OverloadedStrings #-}

module Redis (connectRedis, assignQueueAndReturn) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Database.Redis as R

integerToByteString = BSC.pack . show

-- Set the <value> for the <key> only if it doesn exist and return it
atomicSetGet :: BS.ByteString -> BS.ByteString -> Int -> R.Redis (Either R.Reply (Maybe BS.ByteString))
atomicSetGet key value expire =
  R.sendRequest ["SET", key, value, "NX", "PX", integerToByteString expire]

createAffinityKey :: BS.ByteString -> BS.ByteString
createAffinityKey = (<>) "queue_for:"

connectRedis :: IO R.Connection
connectRedis = R.checkedConnect R.defaultConnectInfo

assignQueueAndReturn :: BS.ByteString -> Int -> R.Connection -> IO (Either R.Reply (Maybe BS.ByteString))
assignQueueAndReturn affinityValue expire connection =
  R.runRedis connection $ atomicSetGet key affinityValue expire
  where
    key = createAffinityKey affinityValue
