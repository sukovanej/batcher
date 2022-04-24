{-# LANGUAGE InstanceSigs #-}

module Batcher.Logger (createDebugLogger, Logger (..)) where

import Data.List

type LoggerPath = String

class Logger a where
  logDebug :: Show s => a -> s -> IO ()
  logInfo :: Show s => a -> s -> IO ()
  logWarn :: Show s => a -> s -> IO ()
  logError :: Show s => a -> s -> IO ()
  logNew :: LoggerPath -> a -> a

newtype DebugLogger = DebugLogger
  { path :: [LoggerPath]
  }

createDebugLogger :: LoggerPath -> DebugLogger
createDebugLogger name = DebugLogger {path = [name]}

colorReset = "\x001b[0m"

getColorBySeverity :: String -> String
getColorBySeverity "debug" = "\x001b[34m"
getColorBySeverity "info" = "\x001b[32m"
getColorBySeverity "warn" = "\x001b[33m"
getColorBySeverity "error" = "\x001b[31m"
getColorBySeverity _ = undefined

padSeverity :: String -> String
padSeverity str =
  if strLen < 5
    then (++) str $ replicate (5 - strLen) ' '
    else str
  where
    strLen = length str

logToStdout :: Show s => String -> DebugLogger -> s -> IO ()
logToStdout severity logger msg = putStrLn $ "[" <> color <> padSeverity severity <> colorReset <> "] {" <> loggerPath <> "} " <> show msg
  where
    loggerPath = intercalate "." $ path logger
    color = getColorBySeverity severity

instance Logger DebugLogger where
  logDebug :: Show s => DebugLogger -> s -> IO ()
  logDebug = logToStdout "debug"

  logInfo :: Show s => DebugLogger -> s -> IO ()
  logInfo = logToStdout "info"

  logWarn :: Show s => DebugLogger -> s -> IO ()
  logWarn = logToStdout "warn"

  logError :: Show s => DebugLogger -> s -> IO ()
  logError = logToStdout "error"

  logNew :: LoggerPath -> DebugLogger -> DebugLogger
  logNew name logger = logger {path = path logger ++ [name]}
