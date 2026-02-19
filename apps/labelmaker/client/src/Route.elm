module Route exposing
    ( Route(..)
    , parseUrl
    , routeParser
    )

import Url exposing (Url)
import Url.Parser as Parser exposing (Parser, (</>))


type Route
    = TemplateList
    | TemplateEditor String
    | LabelList
    | LabelEditor String
    | NotFound


parseUrl : Url -> Route
parseUrl url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map TemplateList Parser.top
        , Parser.map TemplateEditor (Parser.s "template" </> Parser.string)
        , Parser.map LabelList (Parser.s "labels")
        , Parser.map LabelEditor (Parser.s "label" </> Parser.string)
        ]
