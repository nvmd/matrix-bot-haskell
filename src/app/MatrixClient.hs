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


import Network.HTTP.Client
import Network.HTTP.Client.TLS
import Network.HTTP.Client (HttpException(..),HttpExceptionContent(..), requestHeaders, requestBody, method, httpLbs, RequestBody(..), parseRequest, Request (requestBody))
import Network.HTTP.Types
-- import Network.HTTP.Types.Status (statusCode)
import Data.Time.Units (Second, TimeUnit(toMicroseconds))

import Data.Aeson
-- import Data.Aeson (Value, encode, decode)
-- import qualified Data.Aeson as A
import Control.Lens ((^?), (<>~),(&),(.~))
import Data.ByteString.Base64

import Data.Aeson (object, (.=), encode)
-- import Data.Text (Text)


import Network.Wreq
import qualified Network.Wreq.Session as Sess

import OpenSSL.Session (context)
import Network.HTTP.Client.OpenSSL

import Control.Exception.Safe as SE
-- import Network.HTTP.Client (HttpException(..),HttpExceptionContent(..))
-- import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy as BS

getWithApi :: Api -> String -> [Header] -> IO (Either (String,Maybe Value) (Maybe Value))
getWithApi api endpointUrl moreHeaders = do
  let endpointGet = withOpenSSL $ Sess.getWith (opts api & headers <>~ moreHeaders)
                                  (sess api) endpointUrl
  runEndpointRequest endpointGet

data Api = Api { opts :: Network.Wreq.Options
               , sess :: Sess.Session
               } deriving Show

mkApi authToken = do
  let moreHeaders = [
        -- (hAuthorization, BS.pack ("Bearer " ++ authToken))
        ]
      opts = defaults & manager .~ Left (opensslManagerSettings context)
                      & headers .~ moreHeaders
  Api opts <$> Sess.newSession

postWithApi :: Api -> String -> [Header] ->  BS.ByteString -> IO (Either (String,Maybe Value) (Maybe Value))
postWithApi api endpointUrl moreHeaders body = do
  let endpointPost = withOpenSSL $ Sess.postWith (opts api & headers <>~ moreHeaders)
                                  (sess api) endpointUrl body
  runEndpointRequest endpointPost

runEndpointRequest reqAction = do
  catch (do r <- reqAction
            return $ Right $ (r ^? Network.Wreq.responseBody) >>= decode)
        (\(e :: HttpException) ->
          return $ Left (displayException e, extractResponseBodyIfAny e))
  where extractResponseBodyIfAny e = case e of
          HttpExceptionRequest _req (StatusCodeException _resp rb) -> decodeStrict rb
          _ -> Nothing

printerApi api msg = do
  putStrLn "printer api"

  printerApiUrl <- getEnv "PRINTER_API"
  putStr "PRINTER_API: "
  putStrLn printerApiUrl

  let url = printerApiUrl
  let requestObject = object [
        -- "text" .= (msg :: Text)
      -- , "qr" .= msg
         "text" .= (msg :: Text)
       , "qr"  .= (msg :: Text)
      --   "text" .= ("matrix-client-haskell" :: Text)
      --  , "number"  .= (30 :: Int)
      --  , "image" .= ("image goes here" :: Text)
      --  , "qr" .= ("TESTESTESTSTST" :: Text)
      --  , "text" .= ("thiswasatext" :: Text)
       ]

  -- let body = BS.empty
  let body = encode requestObject
  res <- postWithApi api url [(hContentType, "application/json")] body
  print res

  -- -- manager <- newManager tlsManagerSettings
  -- manager <- newTlsManagerWith tlsManagerSettings
  -- initialRequest <- parseRequest url
  -- -- let request = initialRequest { method = "GET"
  -- --                              , requestBody = RequestBodyLBS $ encode requestObject
  -- --                              , requestHeaders = [(hContentType, "application/json")]
  -- --                              }
  -- let request = initialRequest { method = "POST"
  --                              , requestBody = RequestBodyLBS $ encode requestObject
  --                              , requestHeaders = [(hContentType, "application/json")]
  --                              }

  -- print request
  -- putStrLn "======"
  -- response <- httpLbs request manager
  -- putStrLn $ "The status code was: " ++ (show $ Network.HTTP.Types.statusCode $ Network.HTTP.Client.responseStatus response)

  -- putStrLn "======"
  -- print $ Network.HTTP.Client.responseBody response

run :: IO ()
run = do

  api <- mkApi ""

  putStrLn "matrix-client-haskell"

  quotePreamble <- getEnv "MATRIXBOT_QUOTE_PREAMBLE"

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
  printerApi api "matrix-client-haskell live: "
  res <- syncPoll sess filter (Just (srNextBatch syncResult)) (Just Online) printTimelines

  return ()
