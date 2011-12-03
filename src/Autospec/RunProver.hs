{-# LANGUAGE ViewPatterns #-}
-- This module could probably be done very generically, as a framework
-- for spawning of a lot of processes to yield results, and combine
-- them. Nice hackage package? Also, processes could be spawned on
-- many different computers, as MPI for C++.
module Autospec.RunProver where

import Autospec.Util (mif)
import Autospec.ToFOL.ProofDatatypes
import Autospec.ToFOL.Core

import Control.Concurrent.Chan
import Control.Concurrent.MVar
import Control.Concurrent
import Control.Monad
import Control.Arrow (first,second)
import Control.Monad.State
import Control.Applicative

import System.Process
import System.IO
import System.Exit
import Data.List
import Data.Maybe

import qualified Data.Map as M
import Data.Map (Map)

import System.Console.CmdArgs

-- Finite Theorem is actually not a result from the prover
data ProverResult = Timeout | Theorem | Falsifiable | Unknown | FiniteTheorem
  deriving (Eq,Ord)

instance Show ProverResult where
  show Timeout       = "timeout"
  show Theorem       = "Theorem"
  show Falsifiable   = "False"
  show Unknown       = "???"
  show FiniteTheorem = "Finite Theorem"

type ProbDesc = (Name,ProofType)
type Problem = Principle String
type Res     = Principle ProverResult

type ResChan  = Chan (ProbDesc,Part ProverResult)
type ProbChan = Chan (ProbDesc,Part String)

runProvers :: Int -> Int -> Maybe FilePath -> [Problem] -> IO [Res]
runProvers processes timeout output problems = do
    probChan <- newChan
    sequence_ [ writeChan probChan ((name,ptype)
                                   ,Part partName (str ++ str') pfail)
              | Principle name ptype str _ parts <- problems
              , Part partName str' pfail <- parts
              ]
--    mapM_ (writeChan probChan) problems
    resChan <- newChan
    ps <- replicateM processes $
               forkIO (worker timeout output probChan resChan)
    res <- getResults resChan problems
    mapM_ killThread ps
    return res

type OutChan = Chan (Maybe Res)

getResults :: ResChan -> [Problem] -> IO [Res]
getResults ch probs = do
    out <- newChan
    -- I was once able to fork this in another thread,
    -- but now it gives mea a thread blocked indefinitely in MVar operation
    evalStateT (getResults' ch out) (probmap,M.empty)
 --   putStrLn "Getting from chan..."
    map fromJust . takeWhile isJust <$> getChanContents out
  where probmap = M.fromList [ ((n,t),length parts)
                             | Principle n t _  _ parts <- probs
                             ]

flattenRes :: Part ProverResult -> ProverResult
flattenRes (Part _ Timeout InfiniteFail) = FiniteTheorem
flattenRes (Part _ r _)                = r

combineRes :: [ProverResult] -> ProverResult
combineRes rs
   | all ((Theorem ==))                                 rs = Theorem
   | all ((||) <$> (Theorem ==) <*> (FiniteTheorem ==)) rs = FiniteTheorem
   | any (Falsifiable ==)                               rs = Falsifiable
   | any (Unknown ==)                                   rs = Unknown
   | otherwise                                             = Timeout

resFromParts :: [Part ProverResult] -> ProverResult
resFromParts = combineRes . map flattenRes

statusFromGroup :: [Res] -> ProverResult
statusFromGroup (map principleDecor -> rs)
   | any (Theorem ==) rs       = Theorem
   | any (FiniteTheorem ==) rs = FiniteTheorem
   | any (Falsifiable ==) rs   = Falsifiable
   | any (Unknown ==) rs       = Unknown
   | otherwise                 = Timeout

getResults' :: ResChan
            -> OutChan      -- ^ We need this channel to get some laziness
            -> StateT (Map ProbDesc Int,Map ProbDesc [Part ProverResult])
                      IO
                      ()
getResults' ch out = mif (M.null <$> gets fst)
                         (lift $ writeChan out Nothing) $ do
    (desc@(name,ptype),res) <- lift $ readChan ch
    let alterFun Nothing   = Just [res]
        alterFun (Just rs) = Just (res:rs)
    modify (second (M.alter alterFun desc))
    left <- M.lookup desc <$> gets fst
    lift $ whenLoud $ putStrLn $ name ++ ", " ++ show ptype ++ ": " ++ show (partDecor res)
    case left of
         Just x | x > 1 -> modify (first (M.adjust pred desc))
                | otherwise -> do modify (first (M.delete desc))
                                  Just parts <- M.lookup desc <$> gets snd
--                                  lift $ putStrLn "Writing to chan..."
                                  lift $ writeChan out $ Just $
                                      Principle (fst desc) (snd desc)
                                                (resFromParts parts)
                                                (error "getResults': pretty proof lost")
                                                parts
         Nothing        -> error $ "Problem " ++ show desc ++ "not left in map?!"
    getResults' ch out

worker :: Int -> Maybe FilePath -> ProbChan -> ResChan -> IO ()
worker timeout output probChan resChan = forever $ do
    (desc@(name,ptype),Part pname str pfail) <- readChan probChan
--     putStrLn $ "Working on " ++ name
    mvar <- newEmptyMVar
    pvar <- newEmptyMVar
    tid <- length str `seq` forkIO $ runProver str mvar pvar
    kid <- forkIO $ do threadDelay (timeout * 1000)
                       pid <- takeMVar pvar
                       killThread tid
                       terminateProcess pid
--                       putStrLn $ name ++ "killed"
                       putMVar mvar Timeout
    -- No handling of storing tptp messasges
    let fname = name ++ "_" ++
                proofTypeFile ptype ++ "_" ++
                pname ++ ".tptp"
    maybe (return ()) (\d -> writeFile (d ++ fname) str) output
    res <- takeMVar mvar
    killThread kid
    killThread tid
    writeChan resChan (desc,Part pname res pfail)

runProver :: String -> MVar ProverResult -> MVar ProcessHandle -> IO ()
runProver str mvar pvar = do
--    putStrLn "Running prover"

    let cmd = "eprover"
        args = words "-tAuto -xAuto --memory-limit=1000 --tptp3-format -s"

    (Just inh, Just outh, _, pid) <-
        createProcess (proc cmd args){ std_in  = CreatePipe,
                                       std_out = CreatePipe,
                                       std_err = Inherit }

    putMVar pvar pid

    -- fork off a thread to start consuming the output
    output  <- hGetContents outh
    outMVar <- newEmptyMVar
    _ <- forkIO $ length output `seq` putMVar outMVar ()

    -- now write and flush any input
    when (not (null str)) $ do hPutStr inh str; hFlush inh
    hClose inh -- done with stdin

    -- wait on the output
    takeMVar outMVar
    hClose outh

    -- wait on the process
    ex <- waitForProcess pid

    out <- case ex of
     ExitSuccess   -> return output
     ExitFailure r ->
       error ("readProcess: " ++ cmd ++
                                     ' ':unwords (map show args) ++
                                     " (exit " ++ show r ++ ")")


    let r | "Theorem" `isInfixOf` out            = Theorem
          | "Unsatisfiable" `isInfixOf` out      = Theorem
          | "CounterSatisfiable" `isInfixOf` out = Falsifiable
          | otherwise                            = Unknown
    putMVar mvar r
