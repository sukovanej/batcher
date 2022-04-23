{-# LANGUAGE InstanceSigs #-}

module Batcher.Logger (createDebugLogger, Logger(..)) where

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

logToStdout :: Show s => LoggerPath -> DebugLogger -> s -> IO ()
logToStdout severity logger msg = putStrLn $ "[" <> severity <> "] {" <> loggerPath <> "} " <> show msg
  where
    loggerPath = intercalate "." $ path logger

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
