{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module Templater.CaseConversion where

import           Data.Text                      ( Text )
import qualified Data.Text                     as T
import           Data.Maybe
import           Data.Functor
import           Data.Text.ICU                  ( Regex )
import qualified Data.Text.ICU                 as ICU

data WordCase = LowerCase | UpperCase | CamelCase | PascalCase | MixedCase
    deriving (Show, Eq)

data WordSeparator =  SpaceSeparator | UnderscoreSeparator | DashSeparator | SlashSeparator | BackslashSeparator | NoSeparator
    deriving (Show, Eq)

data TemplateValue = MultiWordTemplateValue WordCase WordSeparator [Text]
                   | LiteralTemplateValue Text
    deriving (Show, Eq)

wordCase :: TemplateValue -> Maybe WordCase
wordCase (MultiWordTemplateValue wc _ _) = Just wc
wordCase (LiteralTemplateValue _       ) = Nothing

wordSeparator :: TemplateValue -> Maybe WordSeparator
wordSeparator (MultiWordTemplateValue _ ws _) = Just ws
wordSeparator (LiteralTemplateValue _       ) = Nothing

wordCasePatterns :: WordCase -> (Text, Text)
wordCasePatterns LowerCase  = ("[:lower:]+", "[:lower:]+")
wordCasePatterns UpperCase  = ("[:upper:]+", "[:upper:]+")
wordCasePatterns CamelCase  = ("[:lower:]+", "[:upper:][:lower:]*")
wordCasePatterns PascalCase = ("[:upper:][:lower:]*", "[:upper:][:lower:]*")
wordCasePatterns MixedCase =
    ("(?:[:upper:]|[:lower:])*", "(?:[:upper:]|[:lower:])*")

wordCaseApply :: WordCase -> [Text -> Text]
wordCaseApply LowerCase  = repeat T.toLower
wordCaseApply UpperCase  = repeat T.toUpper
wordCaseApply CamelCase  = T.toLower : repeat T.toTitle
wordCaseApply PascalCase = repeat T.toTitle
wordCaseApply MixedCase  = repeat id

separator :: WordSeparator -> Text
separator NoSeparator         = ""
separator SpaceSeparator      = " "
separator UnderscoreSeparator = "_"
separator DashSeparator       = "-"
separator SlashSeparator      = "/"
separator BackslashSeparator  = "\\"

capitalLetterPattern :: Regex
capitalLetterPattern = ICU.regex [] ".(?=[:upper:])|$"

splitOnR :: ICU.Regex -> Text -> [Text]
splitOnR regex text = ICU.findAll regex text
    <&> \m -> ICU.span m <> fromMaybe T.empty (ICU.group 0 m)

splitWords :: WordCase -> WordSeparator -> Text -> [Text]
splitWords _          SpaceSeparator      = T.splitOn " "
splitWords _          UnderscoreSeparator = T.splitOn "_"
splitWords _          DashSeparator       = T.splitOn "-"
splitWords _          SlashSeparator      = T.splitOn "/"
splitWords _          BackslashSeparator  = T.splitOn "\\"
splitWords CamelCase  NoSeparator         = splitOnR capitalLetterPattern
splitWords PascalCase NoSeparator         = splitOnR capitalLetterPattern
splitWords _          NoSeparator         = pure

multiWordPatterns :: [(Regex, Text -> TemplateValue)]
multiWordPatterns =
    [ (build c s, MultiWordTemplateValue c s . splitWords c s)
    | c <- [LowerCase, UpperCase, CamelCase, PascalCase, MixedCase]
    , s <-
        [ SpaceSeparator
        , UnderscoreSeparator
        , DashSeparator
        , SlashSeparator
        , BackslashSeparator
        , NoSeparator
        ]
    ]  where
    build c s =
        let (fw, ow) = wordCasePatterns c
            ws       = separator s
        in  ICU.regex [] ("^" <> fw <> "(?:\\Q" <> ws <> "\\E" <> ow <> ")*$")

textToTemplateValues :: Text -> [TemplateValue]
textToTemplateValues text =
    LiteralTemplateValue text : mapMaybe (uncurry f) multiWordPatterns
    where f p g = ICU.find p text $> g text

templateValueText :: TemplateValue -> Text
templateValueText (LiteralTemplateValue t) = t
templateValueText (MultiWordTemplateValue c s tt) =
    T.intercalate (separator s) (zipWith ($) (wordCaseApply c) tt)