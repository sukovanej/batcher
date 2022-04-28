{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Batcher.Logger (createDebugLogger, DebugLogger, HasLogger (..)) where

import Control.Monad
import Control.Monad.IO.Class
import Data.List

type LoggerPath = String

data LogSeverity = Debug | Info | Warn | Error

class HasLogger a where
  logOut :: Show s => a -> LogSeverity -> s -> IO ()
  logNew :: a -> LoggerPath -> a

  logDebug :: Show s => a -> s -> IO ()
  logDebug l = logOut l Debug

  logInfo :: Show s => a -> s -> IO ()
  logInfo l = logOut l Info

  logWarn :: Show s => a -> s -> IO ()
  logWarn l = logOut l Warn

  logError :: Show s => a -> s -> IO ()
  logError l = logOut l Error

newtype DebugLogger = DebugLogger
  { path :: [LoggerPath]
  }

createDebugLogger :: LoggerPath -> DebugLogger
createDebugLogger name = DebugLogger {path = [name]}

colorReset = "\x001b[0m"

getColorBySeverity :: LogSeverity -> String
getColorBySeverity Debug = "\x001b[34m"
getColorBySeverity Info = "\x001b[32m"
getColorBySeverity Warn = "\x001b[33m"
getColorBySeverity Error = "\x001b[31m"

getTextBySeverity :: LogSeverity -> String
getTextBySeverity Debug = "debug"
getTextBySeverity Info = "info"
getTextBySeverity Warn = "warn"
getTextBySeverity Error = "error"

padSeverity :: String -> String
padSeverity str =
  if strLen < 5
    then (++) str $ replicate (5 - strLen) ' '
    else str
  where
    strLen = length str

instance HasLogger DebugLogger where
  logOut :: Show s => DebugLogger -> LogSeverity -> s -> IO ()
  logOut logger severity msg = putStrLn $ "[" <> color <> severityText <> colorReset <> "] {" <> loggerPath <> "} " <> show msg
    where
      loggerPath = intercalate "." $ path logger
      color = getColorBySeverity severity
      severityText = padSeverity . getTextBySeverity $ severity

  logNew :: DebugLogger -> LoggerPath -> DebugLogger
  logNew logger name = logger {path = path logger ++ [name]}
