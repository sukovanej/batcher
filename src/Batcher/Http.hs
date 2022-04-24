{-# LANGUAGE OverloadedStrings #-}

module Batcher.Http (runHttpApplication) where

import Batcher.Logger (Logger (..))
import Batcher.Models (CreateCallbackQueueFn, PublishProcessingFn, QueueAlreadyAssigned, RequestBody, ResponseQueue, ResponseBody, AffinityValue)
import Batcher.Queues (QueueName, QueuesStorage, getRandomQueue)
import Batcher.Redis (RedisConnection, assignQueueAndReturn)
import Data.Aeson (FromJSON, Key, Object, ToJSONKey (toJSONKey), Value (Object), decode, encode)
import Data.Aeson.Types (parseMaybe, (.:))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString.Lazy as LBS
import Data.Either
import Data.Functor
import Data.Maybe (fromMaybe)
import qualified Network.AMQP as AMQP
import qualified Network.HTTP.Types as HTTPT
import qualified Network.Wai as WAI
import qualified Network.Wai.Handler.Warp as WARP
import Batcher.Worker (blockForAsyncResponse)

type JsonPath = [Key]

afinityKey = ["reservation_request", "booking_id"]

queueCacheExpiration = 10 * 1000

pollingMiliseconds = 5

runHttpApplication :: Logger l => l -> QueuesStorage -> RedisConnection -> PublishProcessingFn -> CreateCallbackQueueFn -> IO ()
runHttpApplication logger queuesStorage redisConnection publishProcessing createCallbackQueue =
  WARP.run 8080 application
  where
    application = httpApplication logger queuesStorage redisConnection publishProcessing createCallbackQueue

httpApplication :: Logger l => l -> QueuesStorage -> RedisConnection -> PublishProcessingFn -> CreateCallbackQueueFn -> WAI.Application
httpApplication logger queuesStorage redisConnection publishProcessing createCallbackQueue request respond = do
  logInfo logger "Request received"
  body <- getWholeRequestBody request
  let maybeAffinityValue = getAffinityValue afinityKey body <&> encode <&> LBS.toStrict
  response <- processRequest logger body queuesStorage publishProcessing createCallbackQueue redisConnection maybeAffinityValue
  respond response

processRequest :: Logger l => l -> RequestBody -> QueuesStorage -> PublishProcessingFn -> CreateCallbackQueueFn -> RedisConnection -> Maybe QueueName -> IO WAI.Response
processRequest _ _ _ _ _ _ Nothing = return $ WAI.responseLBS HTTPT.status200 [] (LBS.fromStrict "shit happened")
processRequest logger body queuesStorage publishProcessing createCallbackQueue redisConnection (Just affinityValue) = do
  randomQueue <- getRandomQueue queuesStorage

  logDebug logger $ "Got a queue: " <> randomQueue

  let redisLogger = logNew "redis" logger
  redisResult <- assignQueueAndReturn redisLogger randomQueue affinityValue queueCacheExpiration redisConnection

  logDebug logger $ "Redis result: " <> show redisResult

  maybeResponse <- case redisResult of
    Right (alreadyAssigned, Just maybeQueueName) ->
      Just <$> processAssignedQueue logger publishProcessing createCallbackQueue body alreadyAssigned maybeQueueName affinityValue
    Right (alreadyAssigned, Nothing) ->
      logError logger "No queue returned from redis" $> Nothing
    Left reply -> do
      logError logger ("Redis error response" <> show reply) $> Nothing

  return $ WAI.responseLBS HTTPT.status200 [] (LBS.fromStrict $ fromMaybe "shit happened" maybeResponse)

processAssignedQueue :: Logger l => l -> PublishProcessingFn -> CreateCallbackQueueFn -> RequestBody -> QueueAlreadyAssigned -> QueueName -> AffinityValue -> IO ResponseBody
processAssignedQueue logger publishProcessing createCallbackQueue body queueAlreadyAssigned queueName affinityValue = do
  logInfo logger $ "Queue found: " <> queueName

  if queueAlreadyAssigned
    then logDebug logger "Processing queue already assigned"
    else logDebug logger "I assigned the processing queue"

  (responseQueue, channel) <- createCallbackQueue
  publishProcessing queueName body responseQueue affinityValue
  logInfo logger $ "Waiting for response on queue " <> responseQueue
  response <- blockForAsyncResponse pollingMiliseconds channel responseQueue
  logInfo logger "Response received"
  return response

getAffinityValue :: JsonPath -> RequestBody -> Maybe Value
getAffinityValue fieldName body = decode body' >>= getFieldFromJson fieldName
  where
    body' = LBS.fromStrict body

getWholeRequestBody :: WAI.Request -> IO BS.ByteString
getWholeRequestBody request = do
  bodyChunk <- WAI.getRequestBodyChunk request
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
