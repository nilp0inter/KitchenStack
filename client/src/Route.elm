module Route exposing
    ( Route(..)
    , parseUrl
    , routeParser
    )

import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser)


type Route
    = Dashboard
    | NewBatch
    | ItemDetail String
    | BatchDetail String
    | History
    | ContainerTypes
    | Ingredients
    | Recipes
    | NotFound


parseUrl : Url -> Route
parseUrl url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Dashboard Parser.top
        , Parser.map NewBatch (Parser.s "new")
        , Parser.map ItemDetail (Parser.s "item" </> Parser.string)
        , Parser.map BatchDetail (Parser.s "batch" </> Parser.string)
        , Parser.map History (Parser.s "history")
        , Parser.map ContainerTypes (Parser.s "containers")
        , Parser.map Ingredients (Parser.s "ingredients")
        , Parser.map Recipes (Parser.s "recipes")
        ]
