-- Part of this code is taken and adapted from:
-- https://wiki.haskell.org/WxHaskell/Quick_start#Hello_world_in_wxHaskell
module Main where

import Prelude hiding ((.))
import Control.Category
import Control.Monad
import Data.IORef
import Data.MonadicStreamFunction
import Graphics.UI.WX

main :: IO ()
main = start hello

hello :: IO ()
hello = do
  f      <- frame      []
  lenLbl <- staticText f [ text := "0" ]
  entry  <- textEntry  f []
  quit   <- button     f [ text := "Quit", on command := close f ]

  -- Reactive network
  let appMSF =
        labelTextSk lenLbl . arr (show.length) . textEntryTextSg entry

  -- appMSF =
  --   textEntryTextSg entry >>> arr (show.length) >>> labelTextSk lenLbl

  hndlr <- pushReactimate_ appMSF 

  set entry [ on update := hndlr ]
  
  set f [layout := margin 10 (column 5 [ floatCentre (widget lenLbl)
                                       , floatCentre (widget entry)
                                       , floatCentre (widget quit)
                                       ] )]


-- * Auxiliary definitions

-- ** Adhoc Dunai-WX backend
textEntryTextSg :: TextCtrl a -> MStream IO String
textEntryTextSg entry = liftMStreamF_ (get entry text)

labelTextSk :: StaticText a -> MSink IO String
labelTextSk lbl = liftMStreamF $ setJust lbl text
  -- (\t -> set lbl [ text := t ])

-- ** MSF-related definitions and extensions
type MSink m a = MStreamF m a ()

-- | Run an MSF on an input sample step by step, using an IORef to store the
-- continuation.
pushReactimate :: MStreamF IO a b -> IO (a -> IO b)
pushReactimate msf = do
  msfRef <- newIORef msf
  return $ \a -> do
              msf' <- readIORef msfRef
              (b, msf'') <- unMStreamF msf' a
              writeIORef msfRef msf''
              return b

-- | Run one step of an MSF on () streams, internally storing the
-- continuation.
pushReactimate_ :: MStreamF IO () () -> IO (IO ())
pushReactimate_ msf = do
  f <- pushReactimate msf
  return (void (f ()))

-- ** Auxiliary WX functions
setJust :: widget -> Attr widget attr -> attr -> IO ()
setJust c p v = set c [ p := v ]

-- ** Keera Hails - WX bridget on top of Dunai
type ReactiveValueRO m a = MStream m a
type ReactiveValueWO m a = MSink   m a
type ReactiveValueRW m a = (MStream m a, MSink m a)

reactiveWXFieldRO :: widget -> Attr widget attr -> ReactiveValueRO IO attr
reactiveWXFieldRO widget attr = liftMStreamF_ (get widget attr)

reactiveWXFieldWO :: widget -> Attr widget attr -> ReactiveValueWO IO attr
reactiveWXFieldWO widget attr = liftMStreamF  (setJust widget attr)

reactiveWXFieldRW :: widget -> Attr widget attr -> ReactiveValueRW IO attr
reactiveWXFieldRW widget attr =
  ( reactiveWXFieldRO widget attr
  , reactiveWXFieldWO widget attr
  )
