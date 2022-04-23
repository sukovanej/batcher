{-# LANGUAGE OverloadedStrings #-}

module Main where

import Batcher (emitMessage, receiveMessage)
import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (replicateM_)
import qualified Data.Text as T
import qualified Database.Redis as R
import Http (runHttpApplication)
import qualified Network.AMQP as AMQP
import Queues (newQueueStorage)
import Redis (connectRedis)

milisecond = 1000

second = 1000 * milisecond

exchange = "batcher-exchange"

main :: IO ()
main = do
  redisConnection <- connectRedis
  return ()

mainApi :: IO ()
mainApi = do
  queuesStorage <- newQueueStorage
  return ()

mainWorker :: IO ()
mainWorker = undefined

runRabbitTest :: IO ()
runRabbitTest = do
  connection <- AMQP.openConnection "127.0.0.1" "/" "guest" "guest"

  publisherChannel <- AMQP.openChannel connection
  subscriberChannel <- AMQP.openChannel connection

  AMQP.declareExchange
    publisherChannel
    AMQP.newExchange
      { AMQP.exchangeName = exchange,
        AMQP.exchangeType = "fanout",
        AMQP.exchangeDurable = False
      }

  receiveMessage subscriberChannel exchange
  periodicallyEmit publisherChannel exchange
  AMQP.closeConnection connection

periodicallyEmit :: AMQP.Channel -> T.Text -> IO ()
periodicallyEmit channel exchange =
  replicateM_ 100 $
    emitMessage channel exchange *> waitOneSecond
  where
    waitOneSecond = threadDelay $ 1 * second
