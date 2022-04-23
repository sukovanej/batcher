{-# LANGUAGE OverloadedStrings #-}

module Http (runHttpApplication) where

import Data.Aeson (FromJSON, Key, Object, ToJSONKey (toJSONKey), Value (Object), decode, encode)
import Data.Aeson.Types (parseMaybe, (.:))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString.Lazy as LBS
import Data.Either (fromRight)
import Data.Functor
import qualified Database.Redis as R
import Network.HTTP.Types (status200)
import Network.Wai (Application, Request, getRequestBodyChunk, responseLBS)
import qualified Network.Wai.Handler.Warp as W
import Queues (QueuesStorage, getRandomQueue)
import Redis (assignQueueAndReturn)
import qualified Network.AMQP as AMQP

type JsonPath = [Key]

afinityKey = ["reservation_request", "booking_id"]

queueCacheExpiration = 60 * 1000

runHttpApplication :: QueuesStorage -> R.Connection -> AMQP.Connection -> IO ()
runHttpApplication queuesStorage redisConnection amqpConnection = W.run 8080 application
  where
    application = httpApplication queuesStorage redisConnection amqpConnection

httpApplication :: QueuesStorage -> R.Connection -> AMQP.Connection -> Application
httpApplication queuesStorage redisConnection amqpConnection request respond = do
  putStrLn " [api] Request received"
  body <- getWholeRequestBody request
  let maybeAffinityValue = getAffinityValue afinityKey body <&> encode <&> LBS.toStrict
  processingQueue <- getProcessingQueue queuesStorage redisConnection maybeAffinityValue
  respond $ responseLBS status200 [] (LBS.fromStrict body)

getProcessingQueue :: QueuesStorage -> R.Connection -> Maybe BS.ByteString -> IO (Maybe BS.ByteString)
getProcessingQueue _ _ Nothing = return Nothing
getProcessingQueue queuesStorage redisConnection (Just affinityValue) = do
  randomQueue <- getRandomQueue queuesStorage
  BSC.putStrLn $ " [api] [DEBUG] Get a queue: " <> randomQueue
  queue <- assignQueueAndReturn randomQueue affinityValue queueCacheExpiration redisConnection
  putStrLn $ " [api] [DEBUG] Queue assigned: " <> show queue
  return $ fromRight Nothing queue

assignQueueForAffinityValue :: Value -> IO (Maybe BS.ByteString)
assignQueueForAffinityValue = undefined

getAffinityValue :: JsonPath -> BS.ByteString -> Maybe Value
getAffinityValue fieldName body = decode body' >>= getFieldFromJson fieldName
  where
    body' = LBS.fromStrict body

getWholeRequestBody :: Request -> IO BS.ByteString
getWholeRequestBody request = do
  bodyChunk <- getRequestBodyChunk request
  if bodyChunk == BS.empty
    then return bodyChunk
    else getWholeRequestBody request <&> (bodyChunk <>)

getFieldFromJson :: JsonPath -> Value -> Maybe Value
getFieldFromJson [] object = Just object
getFieldFromJson (fieldName : path) object =
  getFieldFromJson' fieldName object >>= getFieldFromJson path

getFieldFromJson' :: Key -> Value -> Maybe Value
getFieldFromJson' fieldName (Object object) =
  flip parseMaybe object $
    \obj -> obj .: fieldName
getFieldFromJson' _ _ = Nothing
