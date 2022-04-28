{-# LANGUAGE OverloadedStrings #-}

module Batcher.Http (runHttpApplication, HttpEnv(..)) where

import Batcher.Logger (DebugLogger, HasLogger (..))
import Batcher.Models (AffinityValue, CreateCallbackQueueFn, PublishProcessingFn, QueueAlreadyAssigned, RequestBody, ResponseBody, ResponseQueue)
import Batcher.Queues (QueueName, QueuesStorage, getRandomQueue)
import Batcher.Redis (RedisConnection, assignQueueAndReturn, HasRedisConnection(..))
import Batcher.Worker (blockForAsyncResponse)
import Control.Monad.Reader
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

type JsonPath = [Key]

afinityKey = ["reservation_request", "booking_id"]

queueCacheExpiration = 10 * 1000

pollingMiliseconds = 5

data HttpEnv = HttpEnv
  { envPublishProcessing :: PublishProcessingFn,
    envCreateCallbackQueue :: CreateCallbackQueueFn,
    envQueuesStorage :: QueuesStorage,
    envRedisConnection :: RedisConnection,
    envLog :: DebugLogger
  }

instance HasLogger HttpEnv where
  logOut env = logOut $ envLog env
  logNew env name = env {envLog = logNew (envLog env) name}

instance HasRedisConnection HttpEnv where
  redisConnection = envRedisConnection

runHttpApplication :: HttpEnv -> IO ()
runHttpApplication env =
  WARP.run 8080 $ httpApplication env

httpApplication :: HttpEnv -> WAI.Application
httpApplication env request respond = do
  logInfo env "Request received"
  body <- getWholeRequestBody request
  let maybeAffinityValue = getAffinityValue afinityKey body <&> encode <&> LBS.toStrict
  response <- processRequest env body maybeAffinityValue
  respond response

processRequest :: HttpEnv -> RequestBody -> Maybe QueueName -> IO WAI.Response
processRequest _ _ Nothing = return $ WAI.responseLBS HTTPT.status200 [] (LBS.fromStrict "shit happened")
processRequest env body (Just affinityValue) = do
  randomQueue <- getRandomQueue $ envQueuesStorage env

  logDebug env $ "Got a queue: " <> randomQueue

  let redisEnv = logNew env "redis"
  redisResult <- assignQueueAndReturn redisEnv randomQueue affinityValue queueCacheExpiration

  logDebug env $ "Redis result: " <> show redisResult

  maybeResponse <- case redisResult of
    Right (alreadyAssigned, Just maybeQueueName) ->
      Just <$> processAssignedQueue env body alreadyAssigned maybeQueueName affinityValue
    Right (alreadyAssigned, Nothing) ->
      liftIO $ logError env "No queue returned from redis" $> Nothing
    Left reply -> do
      liftIO $ logError env ("Redis error response" <> show reply) $> Nothing

  return $ WAI.responseLBS HTTPT.status200 [] (LBS.fromStrict $ fromMaybe "shit happened" maybeResponse)

processAssignedQueue :: HttpEnv -> RequestBody -> QueueAlreadyAssigned -> QueueName -> AffinityValue -> IO ResponseBody
processAssignedQueue env body queueAlreadyAssigned queueName affinityValue = do
  logInfo env $ "Queue found: " <> queueName

  if queueAlreadyAssigned
    then logDebug env "Processing queue already assigned"
    else logDebug env "I assigned the processing queue"

  (responseQueue, channel) <- envCreateCallbackQueue env
  envPublishProcessing env queueName body responseQueue affinityValue
  logInfo env $ "Waiting for response on queue " <> responseQueue
  response <- blockForAsyncResponse pollingMiliseconds channel responseQueue
  logInfo env "Response received"
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
