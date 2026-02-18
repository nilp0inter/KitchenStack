module Page.Menu exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

import Dict exposing (Dict)
import Html exposing (Html)
import Page.Menu.Types as MT exposing (..)
import Page.Menu.View as View
import Types exposing (..)


type alias Model =
    MT.Model


type alias Msg =
    MT.Msg


type alias OutMsg =
    MT.OutMsg


init : List BatchSummary -> ( Model, Cmd Msg )
init batches =
    ( { menuItems = groupBatches batches }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        ReceivedBatches batches ->
            ( { model | menuItems = groupBatches batches }, Cmd.none, NoOp )


groupBatches : List BatchSummary -> List MenuItem
groupBatches batches =
    let
        frozenBatches =
            List.filter (\b -> b.frozenCount > 0) batches

        grouped : Dict String (List BatchSummary)
        grouped =
            List.foldl
                (\batch acc ->
                    let
                        existing =
                            Dict.get batch.name acc |> Maybe.withDefault []
                    in
                    Dict.insert batch.name (batch :: existing) acc
                )
                Dict.empty
                frozenBatches

        toMenuItem : String -> List BatchSummary -> MenuItem
        toMenuItem name batchList =
            { name = name
            , image =
                batchList
                    |> List.filterMap .image
                    |> List.head
            , ingredients =
                batchList
                    |> List.head
                    |> Maybe.map .ingredients
                    |> Maybe.withDefault ""
            , frozenCount =
                List.foldl (\b acc -> acc + b.frozenCount) 0 batchList
            , nearestExpiry =
                batchList
                    |> List.filterMap .expiryDate
                    |> List.sort
                    |> List.head
                    |> Maybe.withDefault ""
            }

        items =
            Dict.toList grouped
                |> List.map (\( name, batchList ) -> toMenuItem name batchList)
                |> List.sortBy .nearestExpiry
    in
    items


view : Model -> Html Msg
view =
    View.view
