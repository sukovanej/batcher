module Batcher.SyncPublisher (publishSync) where

import qualified Network.AMQP as AMQP

publishSync :: AMQP.Connection -> IO ()
publishSync = undefined
