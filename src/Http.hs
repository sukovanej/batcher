{-# LANGUAGE OverloadedStrings #-}

module Http (runHttpApplication) where

import Data.Aeson (FromJSON, Key, Object, ToJSONKey (toJSONKey), Value (Object), decode, encode)
import Data.Aeson.Types (parseMaybe, (.:))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Data.Either (fromRight)
import Data.Functor
import qualified Database.Redis as R
import Network.HTTP.Types (status200)
import Network.Wai (Application, Request, getRequestBodyChunk, responseLBS)
import qualified Network.Wai.Handler.Warp as W
import Queues (QueuesStorage, getRandomQueue)
import Redis (assignQueueAndReturn)

type JsonPath = [Key]

afinityKey = ["reservation_request", "booking_id"]

queueCacheExpiration = 1000

runHttpApplication :: QueuesStorage -> R.Connection -> IO ()
runHttpApplication queuesStorage redisConnection = W.run 8080 application
  where
    application = httpApplication queuesStorage redisConnection

httpApplication :: QueuesStorage -> R.Connection -> Application
httpApplication queuesStorage redisConnection request respond = do
  body <- getWholeRequestBody request
  let maybeAffinityValue = getAffinityValue afinityKey body <&> encode <&> LBS.toStrict
  processingQueue <- getProcessingQueue queuesStorage redisConnection maybeAffinityValue
  respond $ responseLBS status200 [] (LBS.fromStrict body)

getProcessingQueue :: QueuesStorage -> R.Connection -> Maybe BS.ByteString -> IO (Maybe BS.ByteString)
getProcessingQueue _ _ Nothing = pure Nothing
getProcessingQueue queuesStorage redisConnection (Just affinityValue) = do
  randomQueue <- getRandomQueue queuesStorage
  queue <- assignQueueAndReturn randomQueue affinityValue queueCacheExpiration redisConnection
  return $ either (const Nothing) Just queue

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
