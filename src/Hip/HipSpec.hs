{-# LANGUAGE RecordWildCards #-}
module Hip.HipSpec (hipSpec, module Test.QuickSpec.Term) where

import Test.QuickSpec.Term
import qualified Test.QuickSpec.Term as T
import Test.QuickSpec.Equations
import Test.QuickSpec.CongruenceClosure

import Hip.Util
import Hip.Trans.MakeTheory
import Hip.Trans.Theory
import Hip.Messages
import Hip.Params as P
import Hip.Trans.Parser
import Hip.Trans.Core as C
import Hip.Trans.Pretty
import Hip.FromHaskell.FromHaskell
import Hip.Trans.MakeProofs
import Hip.InvokeATPs
import Hip.Trans.ProofDatatypes (propMatter)
import qualified Hip.Trans.ProofDatatypes as PD
import Hip.ResultDatatypes
import Hip.Provers

import Language.TPTP.Pretty

import Data.List
import Data.Maybe
import Data.Typeable
import Data.Char
import Data.Ord
import Data.Tuple
import Data.Function

import Control.Monad.State
import Control.Monad
import Control.Applicative
import Control.Arrow ((***),(&&&),second,first)

import System.IO
import System.Console.CmdArgs hiding (summary,name)
import System.Exit (exitFailure,exitSuccess)

type QSEq = (Term Symbol,Term Symbol)

showEq :: QSEq -> String
showEq (lhs,rhs) = show lhs ++ " = " ++ show rhs

csv :: [String] -> String
csv = intercalate ", "


-- (sat p,unsat p (at most n),rest)
getUpTo :: Int -> (a -> [a] -> Bool) -> [a] -> [a] -> ([a],[a],[a])
getUpTo 0 p xs     ys = ([],[],xs)
getUpTo n p []     ys = ([],[],[])
getUpTo n p (x:xs) ys | p x ys    = let (s,u,r) = getUpTo n     p xs (x:ys) in (x:s,  u,r)
                      | otherwise = let (s,u,r) = getUpTo (n-1) p xs (x:ys) in (  s,x:u,r)

deep :: Params -> Theory -> [Symbol] -> Int -> [Term Symbol] -> [QSEq] -> IO ([Prop],[QSEq])
deep params theory ctxt depth univ eqs = loop (initPrune ctxt univ) eqs [] [] False
  where
    chunks = batchsize params

    loop :: PruneState -> [QSEq] -> [QSEq] -> [Prop] -> Bool -> IO ([Prop],[QSEq])
    loop ps@(_,cc) [] failed proved True  = putStrLn "Loop!" >> loop ps failed [] proved False
    loop ps@(_,cc) [] failed proved False = return (reverse proved,failed)
    loop ps@(_,cc) eqs failed proved retry = do

      let discard eq failedacc = any (isomorphicTo eq) failedacc || evalCC cc (uncurry canDerive eq)

          (renamings,tryEqs,nextEqs) = getUpTo chunks discard eqs failed

      unless (null renamings) $ putStrLn $
         "Discarding renamings and subsumptions: " ++ csv (map showEq renamings)

      res <- tryProve params (map (uncurry termsToProp) tryEqs) theory proved

      let (successes,failures) = (map fst *** map fst) (partition snd res)
          (_,ps') = doPrune (const True) ctxt depth (map propQSTerms successes) [] ps
          failureEqs = map propQSTerms failures

      if null successes
          then loop ps nextEqs (failed ++ failureEqs) proved retry
          else do
              let (_,ps') = doPrune (const True) ctxt depth (map propQSTerms successes) [] ps
                  failed' = failed ++ failureEqs
                  (cand,failedWoCand) = first (sortBy (comparing equationOrder) . nub . concat)
                                      $ flip runState failed'
                                      $ forM successes
                                      $ \prop -> do failed <- get
                                                    let eq = propQSTerms prop
                                                        (cand,failed') = instancesOf ps eq failed
                                                    put failed'
                                                    return cand
              unless (null cand) $ putStrLn $ "Interesting candidates: " ++ csv (map showEq cand)
              loop ps' (cand ++ nextEqs) failedWoCand (proved ++ successes) True

    isomorphicTo :: QSEq -> QSEq -> Bool
    e1 `isomorphicTo` e2 =
      case matchEqSkeleton e1 e2 of
        Nothing -> False
        Just xs -> function xs && function (map swap xs)

    matchEqSkeleton :: QSEq -> QSEq -> Maybe [(Symbol, Symbol)]
    matchEqSkeleton (t, u) (t', u') =
      liftM2 (++) (matchSkeleton t t') (matchSkeleton u u')

    matchSkeleton :: Term Symbol -> Term Symbol -> Maybe [(Symbol, Symbol)]
    matchSkeleton (T.Const f) (T.Const g) | f == g = return []
    matchSkeleton (T.Var x) (T.Var y) = return [(x, y)]
    matchSkeleton (T.App t u) (T.App t' u') =
      liftM2 (++) (matchSkeleton t t') (matchSkeleton u u')
    matchSkeleton _ _ = Nothing

    function :: (Ord a, Eq b) => [(a, b)] -> Bool
    function = all singleton . groupBy ((==) `on` fst) . nub . sortBy (comparing fst)
      where singleton xs = length xs == 1

    instancesOf :: PruneState -> QSEq -> [QSEq] -> ([QSEq],[QSEq])
    instancesOf ps new = partition (instanceOf ps new)

    instanceOf :: PruneState -> QSEq -> QSEq -> Bool
    instanceOf ps new cand =
       let (_,(_,cc)) = doPrune (const True) ctxt depth [cand] [] ps
       in  evalCC cc (uncurry canDerive new)

termToExpr :: Term Symbol -> Expr
termToExpr t = case t of
  T.App e1 e2 -> termToExpr e1 `app` termToExpr e2
  T.Var s     -> C.Var (name s)
  T.Const s | (isUpper . head . name $ s) || name s == ":"
                                          || name s == "[]" -> Con (name s) []
            | otherwise                                     -> C.Var (name s)

-- So far only works on arguments with monomorphic, non-exponential types
termsToProp :: Term Symbol -> Term Symbol -> Prop
termsToProp lhs rhs = Prop { proplhs  = termToExpr lhs
                           , proprhs  = termToExpr rhs
                           , propVars = map (name . fst) typedArgs
                           , propName = repr
                           , propType = TyApp (map snd typedArgs ++ [error $ "res on qs prop " ++ repr])
                           , propRepr = repr ++ " (from quickSpec)"
                           , propQSTerms = (lhs,rhs)
                           }
  where
    typedArgs = map (id &&& typeableType . symbTypeRep) (nub (vars lhs ++ vars rhs))
    repr = show lhs ++ " = " ++ show rhs

typeableType :: TypeRep -> Type
typeableType tr
  | tyConName (typeRepTyCon tr) == "Int" = TyVar "a"
  | otherwise = TyCon (tyConName . typeRepTyCon $ tr)
                        (map typeableType (typeRepArgs tr))
     -- where
     --   fixTyConString = reverse . takeWhile (/= '.') . reverse


hipSpec :: FilePath -> [Symbol] -> Int -> IO ()
hipSpec file ctxt depth = do
  hSetBuffering stdout NoBuffering -- LineBuffering

  params@Params{..} <- cmdArgs (hipSpecParams file)

  (eitherds,hsdebug) <- if "hs" `isSuffixOf` file
                            then parseHaskell <$> readFile file
                            else flip (,) []  <$> parseFile file
  (err,ds) <- case eitherds of
                    Left  estr -> putStrLn estr >> return (True,error estr)
                    Right ds'  -> return (False,ds')
  unless err $ do
    -- Output debug of translation
    when dbfh $ do
      putStrLn "Translating from Haskell..."
      mapM_ print (filter (sourceIs FromHaskell) hsdebug)
      putStrLn "Translation from Haskell translation complete."
    -- Output warnings of translation
    when warnings $ mapM_ print (filter isWarning hsdebug)
    -- Output Core and terminate
    when core $ do mapM_ (putStrLn . prettyCore) ds
                   exitSuccess

    let (theory,props,msgs) = makeTheory params ds

     -- Verbose output
    when dbfol $ mapM_ print (filter (sourceIs Trans) msgs)

    -- Warnings
    when warnings $ mapM_ print (filter isWarning msgs)

    let props' | consistency = inconsistentProp : props
               | otherwise   = props

    putStrLn "Translation complete. Generating equivalence classes."

    let classToEqs :: [[Term Symbol]] -> [(Term Symbol,Term Symbol)]
        classToEqs = sortBy (comparing equationOrder)
                   . concatMap ((\(x:xs) -> zip (repeat x) xs) . sort)

    quickSpecClasses <- packLaws depth ctxt True (const True) (const True)

    putStrLn "Equivalence classes:"
    forM_ quickSpecClasses $ \cl -> putStrLn $ intercalate " = " (map show cl)

    putStrLn "With representatives:"
    putStrLn $ unlines (map (\(l,r) -> show l ++ " = " ++ show r)
                            (classToEqs quickSpecClasses))

    let univ = concat quickSpecClasses

    putStrLn "Starting to prove..."

    (qslemmas,qsunproved) <- deep params theory ctxt depth univ (classToEqs quickSpecClasses)

    (unproved,proved) <- parLoop params theory props' qslemmas

    printInfo unproved proved

    return ()

printInfo :: [Prop] -> [Prop] -> IO ()
printInfo unproved proved = do
    let pr xs | null xs   = "(none)"
              | otherwise = intercalate ",\n\t" (map propName xs)
    putStrLn ("Proved: " ++ pr proved)
    putStrLn ("Unproved: " ++ pr unproved)
    putStrLn (show (length proved) ++ "/" ++ show (length (proved ++ unproved)))


-- | Try to prove some properties in a theory, given some lemmas
tryProve :: Params -> [Prop] -> Theory -> [Prop] -> IO [(Prop,Bool)]
tryProve params@(Params{..}) props thy lemmas = do
    let env = Env { reproveTheorems = reprove
                  , timeout         = timeout
                  , store           = output
                  , provers         = proversFromString provers
                  , processes       = processes
                  , propStatuses    = error "main env propStatuses"
                  , propCodes       = error "main env propCodes"
                  }

        (properties,msgs) = second concat
                          . unzip
                          . map (\prop -> theoryToInvocations params thy prop lemmas)
                          $ props

    when dbproof $ mapM_ print (filter (sourceIs MakeProof) msgs)

    when warnings $ mapM_ print (filter isWarning msgs)

    res <- invokeATPs properties env

    forM res $ \property -> do
        let proved = fst (propMatter property) /= None
        when   proved (putStrLn $ bold (color Green ("Proved " ++ PD.propName property ++ "!!")))
        unless proved (putStrLn $ "Failed to prove " ++ PD.propName property ++ ".")
        return (fromMaybe (error "tryProve: lost")
                          (find ((PD.propName property ==) . propName) props)
               ,proved)

proveLoop :: Params -> Theory -> [Prop] -> [Prop] -> IO ([Prop],[Prop])
proveLoop params thy props lemmas = do
   new <- forFind (inspect props) $ \(p,ps) -> snd . head <$> tryProve params [p] thy lemmas
   case new of
     -- Property p was proved and ps are still left to prove
     Just (p,ps) -> do putStrLn ("Proved " ++ propName p ++ ": " ++ propRepr p ++ ".")
                       proveLoop params thy ps (p:lemmas)
     -- No property was proved, return the unproved properties and the proved ones
     Nothing     -> return (props,lemmas)

parLoop :: Params -> Theory -> [Prop] -> [Prop] -> IO ([Prop],[Prop])
parLoop params thy props lemmas = do
    (proved,unproved) <-  (map fst *** map fst) . partition snd
                      <$> tryProve params props thy lemmas
    if null proved then return (props,lemmas)
                   else do putStrLn $ "Adding " ++ show (length proved) ++ " lemmas: " ++ intercalate ", " (map propName proved)
                           parLoop params thy unproved (proved ++ lemmas)


