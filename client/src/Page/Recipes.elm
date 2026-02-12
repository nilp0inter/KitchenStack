module Page.Recipes exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

import Api
import Components.MarkdownEditor as MarkdownEditor
import Data.Recipe
import Html exposing (Html)
import Http
import Page.Recipes.Types as RT exposing (..)
import Page.Recipes.View as View
import Types exposing (..)


type alias Model = RT.Model
type alias Msg = RT.Msg
type alias OutMsg = RT.OutMsg


init : List Recipe -> List Ingredient -> List ContainerType -> List LabelPreset -> ( Model, Cmd Msg )
init recipes ingredients containerTypes labelPresets =
    ( { recipes = recipes
      , ingredients = ingredients
      , containerTypes = containerTypes
      , labelPresets = labelPresets
      , form = Data.Recipe.empty
      , loading = False
      , deleteConfirm = Nothing
      , showSuggestions = False
      , detailsEditor = MarkdownEditor.init ""
      , viewMode = ListMode
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotRecipes result ->
            case result of
                Ok recipes ->
                    ( { model | recipes = recipes, loading = False }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al cargar recetas", notificationType = Error }
                    )

        FormNameChanged name ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | name = name } }, Cmd.none, NoOp )

        FormIngredientInputChanged input ->
            let
                form =
                    model.form

                shouldShowSuggestions =
                    String.length input >= 1
            in
            ( { model
                | form = { form | ingredientInput = input }
                , showSuggestions = shouldShowSuggestions
              }
            , Cmd.none, NoOp )

        AddIngredient ingredientName ->
            let
                trimmedName =
                    String.trim (String.toLower ingredientName)

                form =
                    model.form

                alreadySelected =
                    List.any (\i -> String.toLower i.name == trimmedName) form.selectedIngredients

                isExisting =
                    List.any (\i -> String.toLower i.name == trimmedName) model.ingredients

                newSelectedIngredient =
                    { name = trimmedName
                    , isNew = not isExisting
                    }

                newSelectedIngredients =
                    if trimmedName /= "" && not alreadySelected then
                        form.selectedIngredients ++ [ newSelectedIngredient ]

                    else
                        form.selectedIngredients
            in
            ( { model
                | form =
                    { form
                        | selectedIngredients = newSelectedIngredients
                        , ingredientInput = ""
                    }
                , showSuggestions = False
              }
            , Cmd.none
            , NoOp
            )

        RemoveIngredient ingredientName ->
            let
                form =
                    model.form

                newSelectedIngredients =
                    List.filter (\i -> i.name /= ingredientName) form.selectedIngredients
            in
            ( { model
                | form = { form | selectedIngredients = newSelectedIngredients }
              }
            , Cmd.none
            , NoOp
            )

        FormPortionsChanged portions ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | defaultPortions = portions } }, Cmd.none, NoOp )

        FormContainerChanged containerId ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | defaultContainerId = containerId } }, Cmd.none, NoOp )

        FormLabelPresetChanged presetName ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | defaultLabelPreset = presetName } }, Cmd.none, NoOp )

        DetailsEditorMsg subMsg ->
            ( { model | detailsEditor = MarkdownEditor.update subMsg model.detailsEditor }
            , Cmd.none
            , NoOp
            )

        SaveRecipe ->
            if String.trim model.form.name == "" then
                ( model, Cmd.none, ShowNotification { id = 0, message = "El nombre es obligatorio", notificationType = Error } )

            else if List.isEmpty model.form.selectedIngredients then
                ( model, Cmd.none, ShowNotification { id = 0, message = "Debes añadir al menos un ingrediente", notificationType = Error } )

            else
                let
                    -- Sync details from editor to form
                    form =
                        model.form

                    updatedForm =
                        { form | details = MarkdownEditor.getText model.detailsEditor }
                in
                ( { model | loading = True, form = updatedForm }
                , Api.saveRecipe updatedForm RecipeSaved
                , NoOp
                )

        StartCreate ->
            ( { model
                | form = Data.Recipe.empty
                , detailsEditor = MarkdownEditor.init ""
                , viewMode = FormMode
              }
            , Cmd.none
            , NoOp
            )

        EditRecipe recipe ->
            let
                ingredientNames =
                    String.split ", " recipe.ingredients

                selectedIngredients =
                    List.map
                        (\name ->
                            { name = name
                            , isNew = not (List.any (\i -> String.toLower i.name == String.toLower name) model.ingredients)
                            }
                        )
                        ingredientNames

                details =
                    Maybe.withDefault "" recipe.details
            in
            ( { model
                | form =
                    { name = recipe.name
                    , selectedIngredients = selectedIngredients
                    , ingredientInput = ""
                    , defaultPortions = String.fromInt recipe.defaultPortions
                    , defaultContainerId = Maybe.withDefault "" recipe.defaultContainerId
                    , defaultLabelPreset = Maybe.withDefault "" recipe.defaultLabelPreset
                    , editing = Just recipe.name
                    , details = details
                    }
                , detailsEditor = MarkdownEditor.init details
                , viewMode = FormMode
              }
            , Cmd.none
            , NoOp
            )

        CancelEdit ->
            ( { model | form = Data.Recipe.empty, detailsEditor = MarkdownEditor.init "", viewMode = ListMode }, Cmd.none, NoOp )

        DeleteRecipe name ->
            ( { model | deleteConfirm = Just name }, Cmd.none, NoOp )

        ConfirmDelete name ->
            ( { model | deleteConfirm = Nothing, loading = True }
            , Api.deleteRecipe name RecipeDeleted
            , NoOp
            )

        CancelDelete ->
            ( { model | deleteConfirm = Nothing }, Cmd.none, NoOp )

        RecipeSaved result ->
            case result of
                Ok _ ->
                    ( { model | loading = False, form = Data.Recipe.empty, detailsEditor = MarkdownEditor.init "", viewMode = ListMode }
                    , Api.fetchRecipes GotRecipes
                    , RefreshRecipesWithNotification { id = 0, message = "Receta guardada", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al guardar receta", notificationType = Error }
                    )

        RecipeDeleted result ->
            case result of
                Ok _ ->
                    ( { model | loading = False }
                    , Api.fetchRecipes GotRecipes
                    , RefreshRecipesWithNotification { id = 0, message = "Receta eliminada", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al eliminar receta", notificationType = Error }
                    )

        HideSuggestions ->
            ( { model | showSuggestions = False }, Cmd.none, NoOp )

        IngredientKeyDown key ->
            if key == "Enter" || key == "," then
                let
                    trimmedInput =
                        String.trim model.form.ingredientInput
                in
                if trimmedInput /= "" then
                    update (AddIngredient trimmedInput) model

                else
                    ( model, Cmd.none, NoOp )

            else
                ( model, Cmd.none, NoOp )

        ReceivedIngredients ingredients ->
            ( { model | ingredients = ingredients }, Cmd.none, NoOp )

        ReceivedContainerTypes containerTypes ->
            ( { model | containerTypes = containerTypes }, Cmd.none, NoOp )

        ReceivedRecipes recipes ->
            ( { model | recipes = recipes }, Cmd.none, NoOp )

        ReceivedLabelPresets labelPresets ->
            ( { model | labelPresets = labelPresets }, Cmd.none, NoOp )


view : Model -> Html Msg
view =
    View.view
