{-# LANGUAGE OverloadedStrings #-}

module Batcher.Constants
  ( processingExchangeName,
    syncExchangeName,
    processingResponseExchangeName,
  )
where

import qualified Data.Text as T

processingExchangeName :: T.Text
processingExchangeName = "processing-exchange"

processingResponseExchangeName :: T.Text
processingResponseExchangeName = "processing-response-exchange"

syncExchangeName :: T.Text
syncExchangeName = "sync-exchange"
