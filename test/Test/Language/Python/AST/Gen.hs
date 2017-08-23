{-# language DataKinds #-}
{-# language FlexibleInstances #-}
{-# language KindSignatures #-}
module Test.Language.Python.AST.Gen where

import Papa

import Data.Functor.Compose
import Data.Functor.Sum
import Data.Separated.After (After(..))
import Data.Separated.Before (Before(..))
import Data.Separated.Between (Between(..), Between'(..))
import Hedgehog

import qualified Data.Text as T
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import qualified Language.Python.AST as AST
import qualified Language.Python.AST.Digits as AST
import qualified Language.Python.AST.EscapeSeq as AST
import qualified Language.Python.AST.Keywords as AST
import qualified Language.Python.AST.LongBytesChar as AST
import qualified Language.Python.AST.LongStringChar as AST
import qualified Language.Python.AST.ShortBytesChar as AST
import qualified Language.Python.AST.ShortStringChar as AST
import qualified Language.Python.AST.Symbols as AST

genBefore :: MonadGen m => m s -> m a -> m (Before s a)
genBefore = liftA2 Before

genBeforeF
  :: MonadGen m
  => m s
  -> m (f a)
  -> m (Compose (Before s) f a)
genBeforeF ms = fmap Compose . genBefore ms

genAfter
  :: MonadGen m
  => m s -> m a -> m (After s a)
genAfter = liftA2 After

genBetween
  :: MonadGen m
  => m s -> m t -> m a -> m (Between s t a)
genBetween ms mt ma = Between <$> ms <*> ma <*> mt

genBetweenF
  :: MonadGen m
  => m s
  -> m t
  -> m (f a)
  -> m (Compose (Between s t) f a)
genBetweenF ms mt = fmap Compose . genBetween ms mt

genBetween'
  :: MonadGen m
  => m s -> m a -> m (Between' s a)
genBetween' ms ma = Between' <$> genBetween ms ms ma

genNewlineChar
  :: MonadGen m
  => m AST.NewlineChar
genNewlineChar = Gen.element [AST.CR, AST.LF, AST.CRLF]

genWhitespaceChar
  :: MonadGen m
  => m AST.WhitespaceChar
genWhitespaceChar =
  Gen.choice
    [ pure AST.Space
    , pure AST.Tab
    , AST.Continued <$> genNewlineChar
    ]

genListF
  :: MonadGen m
  => m (f a) -> m (Compose [] f a)
genListF ma =
  Compose <$>
  Gen.list (Range.linear 0 10) ma
  
genMaybeF
  :: MonadGen m
  => m (f a) -> m (Compose Maybe f a)
genMaybeF ma = Compose <$> Gen.maybe ma
    
genWhitespace1
  :: MonadGen m
  => m (NonEmpty AST.WhitespaceChar)
genWhitespace1 = Gen.nonEmpty (Range.linear 1 10) genWhitespaceChar

genWhitespaceBefore
  :: MonadGen m
  => m a
  -> m (Before [AST.WhitespaceChar] a)
genWhitespaceBefore ma = Before <$> genWhitespace <*> ma

genWhitespaceBeforeF
  :: MonadGen m
  => m (f a)
  -> m (Compose (Before [AST.WhitespaceChar]) f a)
genWhitespaceBeforeF = fmap Compose . genWhitespaceBefore

genWhitespaceBefore1
  :: MonadGen m
  => m a
  -> m (Before (NonEmpty AST.WhitespaceChar) a)
genWhitespaceBefore1 ma = Before <$> genWhitespace1 <*> ma

genWhitespaceBefore1F
  :: MonadGen m
  => m (f a)
  -> m (Compose (Before (NonEmpty AST.WhitespaceChar)) f a)
genWhitespaceBefore1F = fmap Compose . genWhitespaceBefore1

genWhitespaceAfter
  :: MonadGen m
  => m a
  -> m (After [AST.WhitespaceChar] a)
genWhitespaceAfter ma = After <$> genWhitespace <*> ma

genWhitespaceAfterF
  :: MonadGen m
  => m (f a)
  -> m (Compose (After [AST.WhitespaceChar]) f a)
genWhitespaceAfterF = fmap Compose . genWhitespaceAfter

genWhitespaceAfter1
  :: MonadGen m
  => m a
  -> m (After (NonEmpty AST.WhitespaceChar) a)
genWhitespaceAfter1 ma = After <$> genWhitespace1 <*> ma

genWhitespaceAfter1F
  :: MonadGen m
  => m (f a)
  -> m (Compose (After (NonEmpty AST.WhitespaceChar)) f a)
genWhitespaceAfter1F = fmap Compose . genWhitespaceAfter1

genWhitespace
  :: MonadGen m
  => m [AST.WhitespaceChar]
genWhitespace = Gen.list (Range.linear 0 10) genWhitespaceChar

genBetweenWhitespace
  :: MonadGen m
  => m a
  -> m (Between' [AST.WhitespaceChar] a)
genBetweenWhitespace = genBetween' genWhitespace

genBetweenWhitespaceF
  :: MonadGen m
  => m (f a)
  -> m (Compose (Between' [AST.WhitespaceChar]) f a)
genBetweenWhitespaceF = fmap Compose . genBetweenWhitespace

genBetweenWhitespace1
  :: MonadGen m
  => m a
  -> m (Between' (NonEmpty AST.WhitespaceChar) a)
genBetweenWhitespace1 = genBetween' genWhitespace1

genBetweenWhitespace1F
  :: MonadGen m
  => m (f a)
  -> m (Compose (Between' (NonEmpty AST.WhitespaceChar)) f a)
genBetweenWhitespace1F = fmap Compose . genBetweenWhitespace1

genIfThenElse
  :: (MonadGen m, GenAtomExpr ctxt)
  => m (AST.IfThenElse ctxt ())
genIfThenElse =
  AST.IfThenElse <$>
  genBetweenWhitespace1F genOrTest <*>
  genWhitespaceBefore1F genTest

genTermOp :: MonadGen m => m AST.TermOp
genTermOp =
  Gen.element
    [ AST.TermMult
    , AST.TermAt
    , AST.TermFloorDiv
    , AST.TermDiv
    , AST.TermMod
    ]

genStarExpr :: (MonadGen m, GenAtomExpr ctxt) => m (AST.StarExpr ctxt ())
genStarExpr =
  AST.StarExpr <$>
  genWhitespaceBeforeF genExpr <*>
  pure ()

genTestlistComp :: (MonadGen m, GenAtomExpr ctxt) => m (AST.TestlistComp ctxt ())
genTestlistComp =
  Gen.choice
    [ AST.TestlistCompFor <$>
      genTestOrStar <*>
      genWhitespaceBeforeF genCompFor <*>
      pure ()
    , AST.TestlistCompList <$>
      genTestOrStar <*>
      genListF
        (genBeforeF (genBetweenWhitespace $ pure AST.Comma) genTestOrStar) <*>
      Gen.maybe (genWhitespaceBefore $ pure AST.Comma) <*>
      pure ()
    ]
  where
    genTestOrStar = Gen.choice [ InL <$> genTest, InR <$> genStarExpr ]

genTestList :: (MonadGen m, GenAtomExpr ctxt) => m (AST.TestList ctxt ())
genTestList =
  AST.TestList <$>
    genTest <*>
    genBeforeF (genBetweenWhitespace $ pure AST.Comma) genTest <*>
    Gen.maybe (genWhitespaceBefore $ pure AST.Comma) <*>
    pure ()

genYieldArg :: (MonadGen m, GenAtomExpr ctxt) => m (AST.YieldArg ctxt ())
genYieldArg =
  Gen.choice
    [ AST.YieldArgFrom <$> genWhitespaceBefore1F genTest <*> pure ()
    , AST.YieldArgList <$> genTestList <*> pure ()
    ]
    
genYieldExpr :: MonadGen m => m (AST.YieldExpr ())
genYieldExpr =
  AST.YieldExpr <$>
  genMaybeF (genWhitespaceBefore1F genYieldArg) <*>
  pure ()

genDictOrSetMaker :: (MonadGen m, GenAtomExpr ctxt) => m (AST.DictOrSetMaker ctxt ())
genDictOrSetMaker = pure AST.DictOrSetMaker

genDigit :: MonadGen m => m AST.Digit
genDigit =
  Gen.element
    [ AST.Digit_0
    , AST.Digit_1
    , AST.Digit_2
    , AST.Digit_3
    , AST.Digit_4
    , AST.Digit_5
    , AST.Digit_6
    , AST.Digit_7
    , AST.Digit_8
    , AST.Digit_9
    ]

genNonZeroDigit :: MonadGen m => m AST.NonZeroDigit
genNonZeroDigit =
  Gen.element
    [ AST.NonZeroDigit_1
    , AST.NonZeroDigit_2
    , AST.NonZeroDigit_3
    , AST.NonZeroDigit_4
    , AST.NonZeroDigit_5
    , AST.NonZeroDigit_6
    , AST.NonZeroDigit_7
    , AST.NonZeroDigit_8
    , AST.NonZeroDigit_9
    ]
    
genOctDigit :: MonadGen m => m AST.OctDigit
genOctDigit =
  Gen.element
    [ AST.OctDigit_0
    , AST.OctDigit_1
    , AST.OctDigit_2
    , AST.OctDigit_3
    , AST.OctDigit_4
    , AST.OctDigit_5
    , AST.OctDigit_6
    , AST.OctDigit_7
    ]
    
genHexDigit :: MonadGen m => m AST.HexDigit
genHexDigit =
  Gen.element
    [ AST.HexDigit_0
    , AST.HexDigit_1
    , AST.HexDigit_2
    , AST.HexDigit_3
    , AST.HexDigit_4
    , AST.HexDigit_5
    , AST.HexDigit_6
    , AST.HexDigit_7
    , AST.HexDigit_8
    , AST.HexDigit_9
    , AST.HexDigit_a
    , AST.HexDigit_A
    , AST.HexDigit_b
    , AST.HexDigit_B
    , AST.HexDigit_c
    , AST.HexDigit_C
    , AST.HexDigit_d
    , AST.HexDigit_D
    , AST.HexDigit_e
    , AST.HexDigit_E
    , AST.HexDigit_f
    , AST.HexDigit_F
    ]
    
genBinDigit :: MonadGen m => m AST.BinDigit
genBinDigit = Gen.element [AST.BinDigit_0, AST.BinDigit_1]

genInteger :: MonadGen m => m (AST.Integer' ())
genInteger =
  Gen.choice
    [ AST.IntegerDecimal <$>
      Gen.choice
        [ Left <$>
          liftA2 (,) genNonZeroDigit (Gen.list (Range.linear 0 10) genDigit)
        , Right <$> Gen.nonEmpty (Range.linear 1 10) (pure AST.Zero)
        ] <*>
      pure ()
    , AST.IntegerOct <$>
      genBefore
        (Gen.element [Left AST.Char_o, Right AST.Char_O])
        (Gen.nonEmpty (Range.linear 1 10) genOctDigit) <*>
      pure ()
    , AST.IntegerHex <$>
      genBefore
        (Gen.element [Left AST.Char_x, Right AST.Char_X])
        (Gen.nonEmpty (Range.linear 1 10) genHexDigit) <*>
      pure ()
    , AST.IntegerBin <$>
      genBefore
        (Gen.element [Left AST.Char_b, Right AST.Char_B])
        (Gen.nonEmpty (Range.linear 1 10) genBinDigit) <*>
      pure ()
    ]

genFloat :: MonadGen m => m (AST.Float' ())
genFloat =
  Gen.choice
    [ AST.FloatNoDecimal <$>
      someDigits <*>
      Gen.maybe
        (genBefore genE someDigits) <*>
      pure ()
    , AST.FloatDecimalNoBase <$>
      someDigits <*>
      Gen.maybe (genBefore genE someDigits) <*>
      pure ()
    , AST.FloatDecimalBase <$>
      someDigits <*>
      genMaybeF someDigits <*>
      Gen.maybe (genBefore genE someDigits) <*>
      pure ()
    ]
  where
    someDigits = Gen.nonEmpty (Range.linear 0 10) genDigit
    genE = Gen.element [Left AST.Char_e, Right AST.Char_E]

genStringPrefix :: MonadGen m => m AST.StringPrefix
genStringPrefix =
  Gen.element
    [ AST.StringPrefix_r
    , AST.StringPrefix_u
    , AST.StringPrefix_R
    , AST.StringPrefix_U
    ]

genShortStringCharSingle
  :: MonadGen m
  => m (AST.ShortStringChar AST.SingleQuote)
genShortStringCharSingle =
  Gen.just (fmap (^? AST._ShortStringCharSingle) Gen.ascii)

genShortStringCharDouble
  :: MonadGen m
  => m (AST.ShortStringChar AST.DoubleQuote)
genShortStringCharDouble =
  Gen.just (fmap (^? AST._ShortStringCharDouble) Gen.ascii)

genShortString :: MonadGen m => m (AST.ShortString ())
genShortString =
  Gen.choice
    [ AST.ShortStringSingle <$>
      Gen.list
        (Range.linear 0 200)
        (Gen.choice
          [ Left <$> genShortStringCharSingle
          , Right <$> genEscapeSeq
          ]) <*>
      pure ()
    , AST.ShortStringDouble <$>
      Gen.list
        (Range.linear 0 200)
        (Gen.choice
          [ Left <$> genShortStringCharDouble
          , Right <$> genEscapeSeq
          ])<*>
      pure ()
    ]

genLongStringChar
  :: MonadGen m
  => m AST.LongStringChar
genLongStringChar =
  Gen.just (fmap (^? AST._LongStringChar) Gen.ascii)

genLongString :: MonadGen m => m (AST.LongString ())
genLongString =
  Gen.choice
    [ AST.LongStringSingle <$>
      Gen.list
        (Range.linear 0 200)
        (Gen.choice
          [ Left <$> genLongStringChar
          , Right <$> genEscapeSeq
          ]) <*>
      pure ()
    , AST.LongStringDouble <$>
      Gen.list
        (Range.linear 0 200)
        (Gen.choice
          [ Left <$> genLongStringChar
          , Right <$> genEscapeSeq
          ])<*>
      pure ()
    ]

genStringLiteral :: MonadGen m => m (AST.StringLiteral ())
genStringLiteral =
  AST.StringLiteral <$>
  genBeforeF
    (Gen.maybe genStringPrefix)
    (Gen.choice [InL <$> genShortString, InR <$> genLongString]) <*>
  pure ()

genLongBytesChar
  :: MonadGen m
  => m AST.LongBytesChar
genLongBytesChar =
  Gen.just (fmap (^? AST._LongBytesChar) Gen.ascii)

genLongBytes :: MonadGen m => m (AST.LongBytes ())
genLongBytes =
  Gen.choice
    [ AST.LongBytesSingle <$>
      Gen.list
        (Range.linear 0 200)
        (Gen.choice
          [ Left <$> Gen.ascii
          , Right <$> genEscapeSeq
          ]) <*>
      pure ()
    , AST.LongBytesDouble <$>
      Gen.list
        (Range.linear 0 200)
        (Gen.choice
          [ Left <$> Gen.ascii
          , Right <$> genEscapeSeq
          ])<*>
      pure ()
    ]

genShortBytesCharSingle
  :: MonadGen m
  => m (AST.ShortBytesChar AST.SingleQuote)
genShortBytesCharSingle =
  Gen.just (fmap (^? AST._ShortBytesCharSingle) Gen.ascii)
  
genShortBytesCharDouble
  :: MonadGen m
  => m (AST.ShortBytesChar AST.DoubleQuote)
genShortBytesCharDouble =
  Gen.just (fmap (^? AST._ShortBytesCharDouble) Gen.ascii)

genEscapeSeq
  :: MonadGen m
  => m AST.EscapeSeq
genEscapeSeq =
  Gen.choice
    [ pure AST.Slash_newline
    , pure AST.Slash_backslash
    , pure AST.Slash_singlequote
    , pure AST.Slash_doublequote
    , pure AST.Slash_a
    , pure AST.Slash_f
    , pure AST.Slash_b
    , pure AST.Slash_n
    , pure AST.Slash_r
    , pure AST.Slash_t
    , pure AST.Slash_v
    , AST.Slash_octal <$> Gen.nonEmpty (Range.linear 1 10) genOctDigit
    , AST.Slash_hex <$> Gen.nonEmpty (Range.linear 1 10) genHexDigit
    ]

genShortBytes :: MonadGen m => m (AST.ShortBytes ())
genShortBytes =
  Gen.choice
    [ AST.ShortBytesSingle <$>
      Gen.list
        (Range.linear 0 200)
        (Gen.choice
          [ Left <$> genShortBytesCharSingle
          , Right <$> genEscapeSeq
          ]) <*>
      pure ()
    , AST.ShortBytesDouble <$>
      Gen.list
        (Range.linear 0 200)
        (Gen.choice
          [ Left <$> genShortBytesCharDouble
          , Right <$> genEscapeSeq
          ])<*>
      pure ()
    ]

genBytesLiteral :: MonadGen m => m (AST.BytesLiteral ())
genBytesLiteral =
  AST.BytesLiteral <$>
  Gen.element
    [ AST.BytesPrefix_b
    , AST.BytesPrefix_B
    , AST.BytesPrefix_br
    , AST.BytesPrefix_Br
    , AST.BytesPrefix_bR
    , AST.BytesPrefix_BR
    , AST.BytesPrefix_rb
    , AST.BytesPrefix_rB
    , AST.BytesPrefix_Rb
    , AST.BytesPrefix_RB
    ] <*>
  Gen.choice [ InL <$> genShortBytes, InR <$> genLongBytes ] <*>
  pure ()

class GenAtomParen (ctxt :: AST.ExprContext) where
  genAtomParen :: MonadGen m => m (AST.Atom ctxt ())

instance GenAtomParen ('AST.FunDef 'AST.Normal) where
  genAtomParen = 
    AST.AtomParenYield <$>
      genBetweenWhitespaceF
        (genMaybeF $
         Gen.choice [InL <$> genYieldExpr, InR <$> genTestlistComp]) <*>
      pure ()

genAtomParenNoYield
  :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Atom ctxt ())
genAtomParenNoYield =
  AST.AtomParenNoYield <$>
  genBetweenWhitespaceF
    (genMaybeF genTestlistComp) <*>
  pure ()

instance GenAtomParen ('AST.FunDef 'AST.Async) where
  genAtomParen = genAtomParenNoYield
  
instance GenAtomParen 'AST.TopLevel where
  genAtomParen = genAtomParenNoYield

genAtom
  :: ( MonadGen m
     , GenAtomParen ctxt
     , GenAtomExpr ctxt
     )
  => m (AST.Atom ctxt ())
genAtom =
  Gen.recursive Gen.choice
    [ AST.AtomIdentifier <$> genIdentifier <*> pure ()  
    , AST.AtomInteger <$> genInteger <*> pure ()  
    , AST.AtomFloat <$> genFloat <*> pure ()  
    , AST.AtomString <$>
      genStringOrBytes <*>
      genListF (genWhitespaceBeforeF genStringOrBytes) <*>
      pure ()  
    , pure $ AST.AtomEllipsis ()
    , pure $ AST.AtomNone ()
    , pure $ AST.AtomTrue ()
    , pure $ AST.AtomFalse ()
    ]
    [ genAtomParen
    , AST.AtomBracket <$>
      genBetweenWhitespaceF (genMaybeF genTestlistComp) <*>
      pure ()  
    -- , AST.AtomCurly <$>
    -- genBetweenWhitespaceF (genMaybeF genDictOrSetMaker) <*>
    -- pure ()  
    ]
  where
    genStringOrBytes =
      Gen.choice [ InL <$> genStringLiteral, InR <$> genBytesLiteral ]

genVarargsList :: (MonadGen m, GenAtomExpr ctxt) => m (AST.VarargsList ctxt ())
genVarargsList = pure AST.VarargsList

genLambdefNocond :: (MonadGen m, GenAtomExpr ctxt) => m (AST.LambdefNocond ctxt ())
genLambdefNocond =
  AST.LambdefNocond <$>
  genMaybeF (genBetweenF genWhitespace1 genWhitespace genVarargsList) <*>
  genWhitespaceBeforeF genTestNocond <*>
  pure ()

genTestNocond :: (MonadGen m, GenAtomExpr ctxt) => m (AST.TestNocond ctxt ())
genTestNocond =
  AST.TestNocond <$>
  Gen.choice [ InL <$> genOrTest {-, InR <$> genLambdefNocond -} ] <*>
  pure ()

genCompIf :: (MonadGen m, GenAtomExpr ctxt) => m (AST.CompIf ctxt ())
genCompIf =
  AST.CompIf <$>
  genWhitespaceBeforeF genTestNocond <*>
  genMaybeF (genWhitespaceBeforeF genCompIter) <*>
  pure ()

genCompIter :: (MonadGen m, GenAtomExpr ctxt) => m (AST.CompIter ctxt ())
genCompIter =
  AST.CompIter <$>
  Gen.choice [ InL <$> genCompFor, InR <$> genCompIf ] <*>
  pure ()

genExprList :: (MonadGen m, GenAtomExpr ctxt) => m (AST.ExprList ctxt ())
genExprList =
  AST.ExprList <$>
  genSumOrStar <*>
  genListF
    (genBeforeF (genBetweenWhitespace $ pure AST.Comma) genSumOrStar) <*>
  pure ()
  where
    genSumOrStar =
      Gen.choice [InL <$> genExpr, InR <$> genStarExpr]

genCompFor :: (MonadGen m, GenAtomExpr ctxt) => m (AST.CompFor ctxt ())
genCompFor =
  AST.CompFor <$>
  genBeforeF
    (genBetweenWhitespace1 $ pure AST.KFor)
    (genWhitespaceAfter1F genExprList) <*>
  genWhitespaceBefore1F genOrTest <*>
  genMaybeF (genWhitespaceBeforeF genCompIter) <*>
  pure ()
  
genArgument :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Argument ctxt ())
genArgument =
  Gen.choice
    [ AST.ArgumentFor <$>
      genTest <*>
      genMaybeF (genWhitespaceBeforeF genCompFor) <*>
      pure ()
    , AST.ArgumentDefault <$>
      genWhitespaceAfterF genTest <*>
      genWhitespaceBeforeF genTest <*>
      pure () 
    , AST.ArgumentUnpack <$>
      Gen.element [Left AST.Asterisk, Right AST.DoubleAsterisk] <*>
      genWhitespaceBeforeF genTest <*>
      pure () 
    ]
    
genArgList :: (MonadGen m, GenAtomExpr ctxt) => m (AST.ArgList ctxt ())
genArgList =
  AST.ArgList <$>
  genArgument <*>
  genListF
    (genBeforeF (genBetweenWhitespace $ pure AST.Comma) genArgument) <*>
  Gen.maybe (genWhitespaceBefore $ pure AST.Comma) <*>
  pure () 

genSliceOp :: (MonadGen m, GenAtomExpr ctxt) => m (AST.SliceOp ctxt ())
genSliceOp =
  AST.SliceOp <$> genMaybeF (genWhitespaceBeforeF genTest) <*> pure ()

genSubscript :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Subscript ctxt ())
genSubscript =
  Gen.choice
    [ AST.SubscriptTest <$> genTest <*> pure ()
    , AST.SubscriptSlice <$>
      genMaybeF (genWhitespaceAfterF genTest) <*>
      genMaybeF (genWhitespaceBeforeF genTest) <*>
      genMaybeF (genWhitespaceBeforeF genSliceOp) <*>
      pure ()
    ]

genSubscriptList :: (MonadGen m, GenAtomExpr ctxt) => m (AST.SubscriptList ctxt ())
genSubscriptList =
  AST.SubscriptList <$>
  genSubscript <*>
  genMaybeF
    (genBeforeF
      (genBetweenWhitespace $ pure AST.Comma)
      genSubscript) <*>
  Gen.maybe (genWhitespaceBefore $ pure AST.Comma) <*>
  pure ()

genIdentifier :: MonadGen m => m (AST.Identifier ())
genIdentifier =
  AST.Identifier <$>
  (T.pack <$> Gen.list
    (Range.linear 1 10)
    (Gen.frequency [(1, Gen.upper), (1, Gen.lower), (26, pure '_')])) <*>
  pure ()

genTrailer :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Trailer ctxt ())
genTrailer =
  Gen.recursive Gen.choice
    [ AST.TrailerAccess <$>
      genWhitespaceBeforeF genIdentifier <*>
      pure ()
    ]
    [ AST.TrailerCall <$>
      genBetweenWhitespaceF (genMaybeF genArgList) <*>
      pure ()
    , AST.TrailerSubscript <$>
      genBetweenWhitespaceF (genMaybeF genSubscriptList) <*>
      pure ()
    ]

class GenAtomExpr (ctxt :: AST.ExprContext) where
  genAtomExpr
    :: ( MonadGen m
       
       )
    => m (AST.AtomExpr ctxt ())

instance GenAtomExpr ('AST.FunDef 'AST.Normal) where
  genAtomExpr = genAtomExprNoAwait
  
instance GenAtomExpr 'AST.TopLevel where
  genAtomExpr = genAtomExprNoAwait
  
instance GenAtomExpr ('AST.FunDef 'AST.Async) where
  genAtomExpr = genAtomExprAwait
    
genAtomExprAwait :: MonadGen m => m (AST.AtomExpr ('AST.FunDef 'AST.Async) ())
genAtomExprAwait =
  AST.AtomExprAwait <$>
  genMaybeF (genWhitespaceAfter1 $ pure AST.KAwait) <*>
  genAtom <*>
  genListF (genWhitespaceBeforeF genTrailer) <*>
  pure ()
  
genAtomExprNoAwait
  :: ( GenAtomExpr ctxt
     , GenAtomParen ctxt
     , MonadGen m
     )
  => m (AST.AtomExpr ctxt ())
genAtomExprNoAwait =
  AST.AtomExprNoAwait <$>
  genAtom <*>
  genListF (genWhitespaceBeforeF genTrailer) <*>
  pure ()
    
genPower :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Power ctxt ())
genPower =
  AST.Power <$>
  genAtomExpr <*>
  genMaybeF
    (genBeforeF
      (genWhitespaceAfter $ pure AST.DoubleAsterisk)
      genFactor) <*>
  pure ()

genFactorOp :: MonadGen m => m AST.FactorOp
genFactorOp =
  Gen.element
    [ AST.FactorNeg
    , AST.FactorPos
    , AST.FactorInv
    ]
    
genFactor :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Factor ctxt ())
genFactor =
  Gen.choice
    [ AST.FactorNone <$>
      genPower <*>
      pure ()
    , AST.FactorSome <$>
      genBeforeF (genWhitespaceAfter genFactorOp) genFactor <*>
      pure ()
    ]

genTerm :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Term ctxt ())
genTerm =
  AST.Term <$>
  genFactor <*>
  genListF
    (genBeforeF
      (genBetweenWhitespace genTermOp)
      genFactor) <*>
  pure ()

genArithExpr :: (MonadGen m, GenAtomExpr ctxt) => m (AST.ArithExpr ctxt ())
genArithExpr =
  AST.ArithExpr <$>
  genTerm <*>
  genListF
    (genBeforeF
      (genBetweenWhitespace $
          Gen.element [Left AST.Plus, Right AST.Minus])
      genTerm) <*>
  pure ()

genShiftExpr :: (MonadGen m, GenAtomExpr ctxt) => m (AST.ShiftExpr ctxt ())
genShiftExpr =
  AST.ShiftExpr <$>
  genArithExpr <*>
  genListF
    (genBeforeF
      (genBetweenWhitespace $
          Gen.element [Left AST.DoubleLT, Right AST.DoubleGT])
      genArithExpr) <*>
  pure ()

genAndExpr :: (MonadGen m, GenAtomExpr ctxt) => m (AST.AndExpr ctxt ())
genAndExpr =
  AST.AndExpr <$>
  genShiftExpr <*>
  genListF
    (genBeforeF
      (genBetweenWhitespace $ pure AST.Ampersand)
      genShiftExpr) <*>
  pure ()

genXorExpr :: (MonadGen m, GenAtomExpr ctxt) => m (AST.XorExpr ctxt ())
genXorExpr =
  AST.XorExpr <$>
  genAndExpr <*>
  genListF
    (genBeforeF
      (genBetweenWhitespace $ pure AST.Caret)
      genAndExpr) <*>
  pure ()

genExpr :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Expr ctxt ())
genExpr =
  AST.Expr <$>
  genXorExpr <*>
  genListF
    (genBeforeF
      (genBetweenWhitespace $ pure AST.Pipe)
      genXorExpr) <*>
  pure ()

genCompOperator :: MonadGen m => m AST.CompOperator
genCompOperator =
  Gen.choice
    [ pure AST.CompLT
    , pure AST.CompGT
    , pure AST.CompEq
    , pure AST.CompGEq
    , pure AST.CompLEq
    , pure AST.CompNEq
    , AST.CompIs <$> genWhitespaceChar
    , AST.CompIn <$> genWhitespaceChar
    , AST.CompIsNot <$> genWhitespace1 <*> genWhitespaceChar
    , AST.CompNotIn <$> genWhitespace1 <*> genWhitespaceChar
    ]

genComparison :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Comparison ctxt ())
genComparison =
  AST.Comparison <$>
  genExpr <*>
  genListF
    (genBeforeF
      (genBetweenWhitespace genCompOperator)
      genExpr) <*>
  pure ()

genNotTest :: (MonadGen m, GenAtomExpr ctxt) => m (AST.NotTest ctxt ())
genNotTest =
  Gen.choice
    [ AST.NotTestNone <$> genComparison <*> pure ()
    , AST.NotTestSome <$>
      genBeforeF
        (genWhitespaceAfter1 $ pure AST.KNot)
        genNotTest <*>
      pure ()
    ]
    
genAndTest :: (MonadGen m, GenAtomExpr ctxt) => m (AST.AndTest ctxt ())
genAndTest =
  AST.AndTest <$>
  genNotTest <*>
  genListF
    (genBeforeF
      (genBetween' genWhitespace1 $ pure AST.KAnd)
      genAndTest) <*>
  pure ()

genOrTest :: (MonadGen m, GenAtomExpr ctxt) => m (AST.OrTest ctxt ())
genOrTest =
  AST.OrTest <$>
  genAndTest <*>
  genListF
    (genBeforeF
      (genBetween' genWhitespace1 $ pure AST.KOr)
      genAndTest) <*>
  pure ()

genTest :: (MonadGen m, GenAtomExpr ctxt) => m (AST.Test ctxt ())
genTest =
  Gen.choice
    [ AST.TestCond <$>
      genOrTest <*>
      (genMaybeF
        (genBeforeF
          genWhitespace1 
          genIfThenElse)) <*>
      pure ()
    -- , pure AST.TestLambdef
    ]
