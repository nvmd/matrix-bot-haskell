{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}
{-# HLINT ignore "Redundant return" #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}
{-# OPTIONS_GHC -Wno-unused-do-bind #-}

module Main where

import Control.Monad.IO.Class (MonadIO, liftIO)


import qualified Data.ByteString.Lazy as BL

import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.Text.Lazy as L
import qualified Data.Text.Encoding as TE (encodeUtf8)

import Data.Aeson
import Data.Aeson.Encode.Pretty ()
import Data.Maybe

import Control.Monad
import Control.Lens


import MatrixClient as MC

-------------------------------------------------------------------------------

main :: IO ()
main = do

  MC.run

  return ()
