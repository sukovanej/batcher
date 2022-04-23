module Batcher.Models (AffinityValue, QueueName, QueueAlreadyAssigned) where

import qualified Data.ByteString as BS

type QueueAlreadyAssigned = Bool

type AffinityValue = BS.ByteString

type QueueName = BS.ByteString
