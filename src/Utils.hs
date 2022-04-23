{-# LANGUAGE OverloadedStrings #-}

module Utils (bodyFor) where

import qualified Data.ByteString.Lazy.Char8 as BL

bodyFor :: String -> BL.ByteString
bodyFor [] = "Hello, world!"
bodyFor xs = BL.pack xs
