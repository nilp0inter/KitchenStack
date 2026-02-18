module Route exposing
    ( Route(..)
    , parseUrl
    , routeParser
    )

import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser)


type Route
    = Menu
    | Inventory
    | NewBatch
    | ItemDetail String
    | BatchDetail String
    | EditBatch String
    | History
    | ContainerTypes
    | Ingredients
    | Recipes
    | LabelDesigner
    | NotFound


parseUrl : Url -> Route
parseUrl url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Menu Parser.top
        , Parser.map Inventory (Parser.s "inventory")
        , Parser.map NewBatch (Parser.s "new")
        , Parser.map ItemDetail (Parser.s "item" </> Parser.string)
        , Parser.map EditBatch (Parser.s "batch" </> Parser.string </> Parser.s "edit")
        , Parser.map BatchDetail (Parser.s "batch" </> Parser.string)
        , Parser.map History (Parser.s "history")
        , Parser.map ContainerTypes (Parser.s "containers")
        , Parser.map Ingredients (Parser.s "ingredients")
        , Parser.map Recipes (Parser.s "recipes")
        , Parser.map LabelDesigner (Parser.s "labels")
        ]
