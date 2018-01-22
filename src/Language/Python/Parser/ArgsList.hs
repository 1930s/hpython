module Language.Python.Parser.ArgsList where

import Papa
import Data.Functor.Sum
import Text.Parser.LookAhead
import Text.Trifecta hiding (Unspaced(..), comma)

import Language.Python.AST.ArgsList hiding (ArgsList)
import Language.Python.IR.ArgsList
import Language.Python.Parser.Combinators
import Language.Python.Parser.SrcInfo
import Language.Python.Parser.Symbols

import Text.Parser.Unspaced

argsListArg
  :: ( DeltaParsing m
     , LookAheadParsing m
     , Functor f
     , Functor name
     )
  => Unspaced m ws
  -> Unspaced m (f SrcInfo)
  -> Unspaced m (name SrcInfo)
  -> Unspaced m (ArgsListArg ws name f SrcInfo)
argsListArg ws p pname =
  annotated $
  ArgsListArg <$>
  pname <*>
  optionalF
    (beforeF (try $ between' (many ws) equals) p)

argsListStarPart
  :: ( DeltaParsing m
     , LookAheadParsing m
     , Functor f
     , Functor name
     )
  => Unspaced m ws
  -> Unspaced m (f SrcInfo)
  -> Unspaced m (name SrcInfo)
  -> Unspaced m (ArgsListStarPart ws name f SrcInfo)
argsListStarPart ws p pname =
  annotated $
  argsListStarPartSome <|>
  pure ArgsListStarPartEmpty
  where
    argsListStarPartSome =
      ArgsListStarPart <$>
      try (beforeF (after (many ws) asterisk) pname) <*>
      manyF
        (beforeF
          (try $
           between' (many ws) comma <*
           notFollowedBy doubleAsterisk)
          (argsListArg ws p pname)) <*>
      optionalF
        (beforeF
          (between' (many ws) comma)
          (argsListDoublestarArg ws pname))

argsListDoublestarArg
  :: ( DeltaParsing m
     , LookAheadParsing m
     , Functor name
     )
  => Unspaced m ws
  -> Unspaced m (name SrcInfo)
  -> Unspaced m (ArgsListDoublestarArg ws name test SrcInfo)
argsListDoublestarArg ws pname =
  annotated $
  ArgsListDoublestarArg <$>
  beforeF (after (many ws) doubleAsterisk) pname

argsList
  :: ( DeltaParsing m
     , LookAheadParsing m
     , Functor f
     , Functor name
     )
  => Unspaced m ws
  -> Unspaced m (f SrcInfo)
  -> Unspaced m (name SrcInfo)
  -> Unspaced m (ArgsList ws name f SrcInfo)
argsList ws p pname = argsListAll <|> argsListArgsKwargs
  where
    argsListAll =
      annotated $
      ArgsListAll <$>
      argsListArg ws p pname <*>
      manyF
        (beforeF
          (try $
           between' (many ws) comma <*
           notFollowedBy asterisk)
          (argsListArg ws p pname)) <*>
      optionalF
        (beforeF
          (between' (many ws) comma)
          (optionalF starOrDouble))

    argsListArgsKwargs =
      annotated $
      ArgsListArgsKwargs <$>
      starOrDouble

    starOrDouble = 
      (InL <$> argsListStarPart ws p pname) <|>
      (InR <$> argsListDoublestarArg ws pname)