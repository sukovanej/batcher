{-# LANGUAGE OverloadedStrings #-}

module Batcher.Http (runHttpApplication) where

import Batcher.Logger (Logger (..))
import Batcher.Models (QueueAlreadyAssigned)
import Batcher.Queues (QueueName, QueuesStorage, getRandomQueue)
import Batcher.Redis (assignQueueAndReturn)
import Data.Aeson (FromJSON, Key, Object, ToJSONKey (toJSONKey), Value (Object), decode, encode)
import Data.Aeson.Types (parseMaybe, (.:))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString.Lazy as LBS
import Data.Either (fromRight)
import Data.Functor
import qualified Database.Redis as R
import qualified Network.AMQP as AMQP
import Network.HTTP.Types (status200)
import Network.Wai (Application, Request, getRequestBodyChunk, responseLBS)
import qualified Network.Wai.Handler.Warp as W

type JsonPath = [Key]

type RequestBody = BS.ByteString

afinityKey = ["reservation_request", "booking_id"]

queueCacheExpiration = 10 * 1000

runHttpApplication :: Logger l => l -> QueuesStorage -> R.Connection -> AMQP.Connection -> IO ()
runHttpApplication logger queuesStorage redisConnection amqpConnection =
  W.run 8080 application
  where
    application = httpApplication logger queuesStorage redisConnection amqpConnection

httpApplication :: Logger l => l -> QueuesStorage -> R.Connection -> AMQP.Connection -> Application
httpApplication logger queuesStorage redisConnection amqpConnection request respond = do
  logInfo logger "Request received"
  body <- getWholeRequestBody request
  let maybeAffinityValue = getAffinityValue afinityKey body <&> encode <&> LBS.toStrict
  processingQueue <- getProcessingQueue logger queuesStorage redisConnection maybeAffinityValue
  respond $ responseLBS status200 [] (LBS.fromStrict body)

getProcessingQueue :: Logger l => l -> QueuesStorage -> R.Connection -> Maybe QueueName -> IO (Maybe QueueName)
getProcessingQueue _ _ _ Nothing = return Nothing
getProcessingQueue logger queuesStorage redisConnection (Just affinityValue) = do
  randomQueue <- getRandomQueue queuesStorage

  logDebug logger $ "Get a queue: " <> randomQueue

  let redisLogger = logNew "redis" logger
  redisResult <- assignQueueAndReturn redisLogger randomQueue affinityValue queueCacheExpiration redisConnection

  logDebug logger $ "Redis result: " <> show redisResult

  case redisResult of
    Right (alreadyAssigned, maybeQueueName) ->
      processAssignedQueue logger alreadyAssigned maybeQueueName
    Left reply ->
      logError logger "" $> Nothing

processAssignedQueue :: Logger l => l -> QueueAlreadyAssigned -> Maybe QueueName -> IO (Maybe QueueName)
processAssignedQueue logger _ Nothing = logError logger "No queue returned from redis" $> Nothing
processAssignedQueue logger queueAlreadyAssigned (Just queue) = do
  logInfo logger $ "Queue found: " <> queue
  if queueAlreadyAssigned 
    then logDebug logger "Gonna send the task"
    -- TODO: setup processing worker
    else logDebug logger "Gonna create the processing worker"

  -- TODO: send task for processing
  return $ Just queue

getAffinityValue :: JsonPath -> RequestBody -> Maybe Value
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
