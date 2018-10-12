{-# language BangPatterns #-}
{-# language LambdaCase #-}
module Language.Python.Internal.Render.Correction where

import Control.Lens.Getter ((^.))
import Control.Lens.Setter ((.~))
import Data.Function ((&))
import Data.List.NonEmpty (NonEmpty(..))

import qualified Data.List.NonEmpty as NonEmpty

import Language.Python.Internal.Syntax.Strings
import Language.Python.Internal.Syntax.Whitespace

-- |
-- Two non-typed single-quoted strings cannot be lexically
-- adjacent, because this would be a parse error
--
-- eg. '''' or """"
--
-- we correct for this by inserting a single space where required
-- '' '' or "" ""
correctAdjacentStrings :: NonEmpty (StringLiteral a) -> NonEmpty (StringLiteral a)
correctAdjacentStrings (a :| []) = a :| []
correctAdjacentStrings (a:|b:cs) =
  if
    _stringLiteralQuoteType a == _stringLiteralQuoteType b &&
    _stringLiteralStringType a == _stringLiteralStringType b &&
    null (a ^. trailingWhitespace) &&
    not (hasStringPrefix b)
  then
    NonEmpty.cons (a & trailingWhitespace .~ [Space]) (correctAdjacentStrings $ b :| cs)
  else
    NonEmpty.cons a (correctAdjacentStrings $ b :| cs)

quoteChar :: QuoteType -> PyChar
quoteChar qt =
  case qt of
    SingleQuote -> Char_esc_singlequote
    DoubleQuote -> Char_esc_doublequote

quote :: QuoteType -> Char
quote qt =
  case qt of
    DoubleQuote -> '\"'
    SingleQuote -> '\''

correctBackslashes :: [PyChar] -> [PyChar]
correctBackslashes [] = []
correctBackslashes [x] =
  case x of
    Char_lit '\\' -> [Char_esc_bslash]
    _ -> [x]
correctBackslashes (x:y:ys) =
  case x of
    Char_lit '\\'
      | isEscape y -> Char_esc_bslash : y : correctBackslashes ys
      | Char_lit '\\' <- y -> Char_esc_bslash : y : correctBackslashes ys
    _ -> x : correctBackslashes (y : ys)

-- | Every quote in a string of a particular quote type should be escaped
correctQuotes :: QuoteType -> [PyChar] -> [PyChar]
correctQuotes qt =
  fmap
    (case qt of
       DoubleQuote -> \case; Char_lit '"' -> Char_esc_doublequote; c -> c
       SingleQuote -> \case; Char_lit '\'' -> Char_esc_singlequote; c -> c)

-- | Literal quotes at the beginning and end of a long (non-raw) string should be escaped
correctInitialFinalQuotes :: QuoteType -> [PyChar] -> [PyChar]
correctInitialFinalQuotes qt = correctFinalQuotes . correctInitialQuotes
  where
    qc = quoteChar qt
    q = quote qt

    -- | Literal quotes at the end of a long (non-raw) string should be escaped
    correctFinalQuotes :: [PyChar] -> [PyChar]
    correctFinalQuotes = snd . go
      where
        go [] = (True, [])
        go (c:cs) =
          case go cs of
            (b, cs') ->
              if b && c == Char_lit q
              then (True, qc : cs')
              else (False, c : cs')

    -- | Every third literal quote at the beginning of a long (non-raw) string should
    -- be escaped
    correctInitialQuotes :: [PyChar] -> [PyChar]
    correctInitialQuotes = go (0::Int)
      where
        go !_ [] = []
        go !n (c:cs) =
          if c == Char_lit q
          then
            if n == 2
            then qc : go (n+1 `mod` 3) cs
            else c : go (n+1 `mod` 3) cs
          else c : cs