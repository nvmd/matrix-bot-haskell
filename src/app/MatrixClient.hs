{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}
{-# HLINT ignore "Redundant return" #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}
{-# OPTIONS_GHC -Wno-unused-do-bind #-}

module MatrixClient where

import System.Environment
import Network.Matrix.Client

import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO

run :: IO ()
run = do

  putStrLn "matrix-client-haskell"

  -- token <- getTokenFromEnv "MATRIX_TOKEN"
  -- sess <- createSession "https://matrix.org" token
  botsMatrixID <- getEnv "MATRIXBOT_ID"
  user <- getEnv "MATRIXBOT_USER"
  pass <- getEnv "MATRIXBOT_PASS"

  (sess, _token) <- loginToken LoginCredentials {
      lUsername = Username $ T.pack user
    , lLoginSecret = Password $ T.pack pass
    , lBaseUrl = "https://matrix.org"
    , lDeviceId = Nothing
    , lInitialDeviceDisplayName = Nothing
  }
  owner <- getTokenOwner sess
  print owner

  let userId = UserID $ T.pack botsMatrixID
  Right filterId <- createFilter sess userId messageFilter
  filter <- getFilter sess userId filterId

  let printEvent re = case reContent re of
        (EventRoomMessage (RoomMessageText mt)) -> do
          printerApi api $ (T.pack quotePreamble) <> unAuthor (reSender re) <> ": " <> (mtBody mt)
          TIO.putStrLn $ unAuthor (reSender re) <> ": " <> (mtBody mt) <> " <<< " <> (T.pack $ show re) <> " >>> "
        _ -> TIO.putStrLn $ T.pack $ show re
  let printRoomEvent room event = TIO.putStr room >> putStr "| " >> printEvent event
  let printRoomEvents (RoomID room, events) = traverse (printRoomEvent room) events
  let printTimelines sr = mapM_ printRoomEvents (getTimelines sr)


  let filter = Nothing
  -- let filter = Just filterId
  Right syncResult <- sync sess filter Nothing (Just Online) Nothing
  putStrLn $ take 512 $ show (getTimelines syncResult)

  putStrLn "Live updates: "
  res <- syncPoll sess filter (Just (srNextBatch syncResult)) (Just Online) printTimelines

  return ()
