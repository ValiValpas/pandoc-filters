{-
Pandoc filter that cleans up internal references to figures and tables (tables soon!).
Compile with:

    ghc --make pandoc-internalref.hs
    
and use in pandoc with

    --filter [PATH]/pandoc-internalref
 -}
module Main where
import System.Environment
import Text.Pandoc.JSON
import Text.Pandoc.Walk (walk, walkM)
import Data.List (stripPrefix, delete)
import Control.Monad ((>=>))

main = toJSONFilter pandocSeq
{-main = putStrLn "a"-}

pandocSeq :: (Maybe Format) -> (Pandoc -> IO Pandoc)
pandocSeq (Just (Format "latex")) = (walkM fixlink) >=> (walkM fixeqlink) >=> baseSeq >=> (walkM latexRef)
pandocSeq (Just (Format "native")) = (walkM fixlink) >=> (walkM fixeqlink) >=> baseSeq >=> (walkM latexRef)
{-pandocSeq _ = return -}
pandocSeq _ = baseSeq

baseSeq :: Pandoc -> IO Pandoc
baseSeq = (walkM floatAttribute)
{-baseSeq = (walkM fixlink) >=> (walkM floatAttribute)-}

-- fix latex internal ref's
fixlink :: Inline -> IO Inline
fixlink (Link attrs txt ('#':ident, x))
    | Just subident <- stripPrefix "fig:" ident = return reflink 
    | Just subident <- stripPrefix "tab:" ident = return reflink 
    | Just subident <- stripPrefix "th:" ident = return reflink 
    | Just subident <- stripPrefix "sec:" ident = return reflink 
    where reflink = Link attrs [RawInline (Format "latex") ("\\autoref{" ++ ident ++ "}")] ("#" ++ ident, x)
fixlink x = return x

fixeqlink :: Inline -> IO Inline
fixeqlink (Link attrs txt ('#':ident, x)) 
    | Just subident <- stripPrefix "eq:" ident = return reflink 
    where reflink = Link attrs [RawInline (Format "latex") ("\\eqref{" ++ ident ++ "}")] ("#" ++ ident, x)
fixeqlink x = return x

-- read attributes into a div
floatAttribute:: Block -> IO Block
floatAttribute (Table caps aligns widths headers rows)
    | attribCaps /= [] = return (Div (ident, classes', []) [Table goodCaps aligns widths headers rows])
    where
        (goodCaps, attribCaps) = break capStartsAttribs caps
        capStartsAttribs (Str capcontent) = head capcontent == '{'
        capStartsAttribs x = False
        classes = [delete '{' (delete '}' str) | Str str <- attribCaps]
        ident   | (head $ head classes) == '#' = tail $ head classes
                | otherwise = ""
        classes'    | (head $ head classes) == '#' = tail classes
                    | otherwise = classes
        {-goodCaps = takeWhile (\a -> ) caps-}
        {-Str lastCap = last caps-}
        {-hasTableAttribs = (head lastCap == '{') && (tail lastCap == '}')-}
floatAttribute x = return x

-- add \label to image captions
latexRef :: Block -> IO Block
latexRef (Para [Image (ident, classes, kvs) caps src]) = 
    return (Para [Image (ident, classes, kvs) (caps ++ [RawInline (Format "tex") ("\\label{" ++ ident ++ "}")]) src])
latexRef (Div (ident, classes, kvs) [Table caps aligns widths headers rows]) = 
    return (Div (ident, classes, kvs)
        [Table (caps ++ [RawInline (Format "tex") ("\\label{" ++ ident ++ "}")]) aligns widths headers rows])
latexRef x = return x
