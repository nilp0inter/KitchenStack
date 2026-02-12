module Page.Ingredients exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

import Api
import Data.Ingredient
import Html exposing (Html)
import Http
import Page.Ingredients.Types as IT exposing (..)
import Page.Ingredients.View as View
import Types exposing (..)


type alias Model = IT.Model
type alias Msg = IT.Msg
type alias OutMsg = IT.OutMsg


init : List Ingredient -> ( Model, Cmd Msg )
init ingredients =
    ( { ingredients = ingredients
      , form = Data.Ingredient.empty
      , loading = False
      , deleteConfirm = Nothing
      , viewMode = ListMode
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotIngredients result ->
            case result of
                Ok ingredients ->
                    ( { model | ingredients = ingredients, loading = False }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al cargar ingredientes", notificationType = Error }
                    )

        FormNameChanged name ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | name = name } }, Cmd.none, NoOp )

        FormExpireDaysChanged days ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | expireDays = days } }, Cmd.none, NoOp )

        FormBestBeforeDaysChanged days ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | bestBeforeDays = days } }, Cmd.none, NoOp )

        SaveIngredient ->
            ( { model | loading = True }
            , Api.saveIngredient model.form IngredientSaved
            , NoOp
            )

        StartCreate ->
            ( { model | form = Data.Ingredient.empty, viewMode = FormMode }
            , Cmd.none
            , NoOp
            )

        EditIngredient ingredient ->
            ( { model
                | form =
                    { name = ingredient.name
                    , expireDays = Maybe.withDefault "" (Maybe.map String.fromInt ingredient.expireDays)
                    , bestBeforeDays = Maybe.withDefault "" (Maybe.map String.fromInt ingredient.bestBeforeDays)
                    , editing = Just ingredient.name
                    }
                , viewMode = FormMode
              }
            , Cmd.none
            , NoOp
            )

        CancelEdit ->
            ( { model | form = Data.Ingredient.empty, viewMode = ListMode }, Cmd.none, NoOp )

        DeleteIngredient name ->
            ( { model | deleteConfirm = Just name }, Cmd.none, NoOp )

        ConfirmDelete name ->
            ( { model | deleteConfirm = Nothing, loading = True }
            , Api.deleteIngredient name IngredientDeleted
            , NoOp
            )

        CancelDelete ->
            ( { model | deleteConfirm = Nothing }, Cmd.none, NoOp )

        IngredientSaved result ->
            case result of
                Ok _ ->
                    ( { model | loading = False, form = Data.Ingredient.empty, viewMode = ListMode }
                    , Api.fetchIngredients GotIngredients
                    , RefreshIngredientsWithNotification { id = 0, message = "Ingrediente guardado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al guardar ingrediente", notificationType = Error }
                    )

        IngredientDeleted result ->
            case result of
                Ok _ ->
                    ( { model | loading = False }
                    , Api.fetchIngredients GotIngredients
                    , RefreshIngredientsWithNotification { id = 0, message = "Ingrediente eliminado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al eliminar ingrediente (puede estar en uso)", notificationType = Error }
                    )

        ReceivedIngredients ingredients ->
            ( { model | ingredients = ingredients }, Cmd.none, NoOp )


view : Model -> Html Msg
view =
    View.view
