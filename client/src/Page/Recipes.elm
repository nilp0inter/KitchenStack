module Page.Recipes exposing
    ( Model
    , Msg
    , OutMsg(..)
    , init
    , update
    , view
    )

import Api
import Html exposing (..)
import Html.Attributes as Attr exposing (class, disabled, id, placeholder, required, selected, title, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as Decode
import Types exposing (..)


type alias Model =
    { recipes : List Recipe
    , ingredients : List Ingredient
    , containerTypes : List ContainerType
    , labelPresets : List LabelPreset
    , form : RecipeForm
    , loading : Bool
    , deleteConfirm : Maybe String
    , showSuggestions : Bool
    }


type Msg
    = GotRecipes (Result Http.Error (List Recipe))
    | FormNameChanged String
    | FormIngredientInputChanged String
    | AddIngredient String
    | RemoveIngredient String
    | FormPortionsChanged String
    | FormContainerChanged String
    | FormLabelPresetChanged String
    | FormDetailsChanged String
    | SaveRecipe
    | EditRecipe Recipe
    | CancelEdit
    | DeleteRecipe String
    | ConfirmDelete String
    | CancelDelete
    | RecipeSaved (Result Http.Error ())
    | RecipeDeleted (Result Http.Error ())
    | HideSuggestions
    | IngredientKeyDown String


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshRecipes


init : List Recipe -> List Ingredient -> List ContainerType -> List LabelPreset -> ( Model, Cmd Msg )
init recipes ingredients containerTypes labelPresets =
    ( { recipes = recipes
      , ingredients = ingredients
      , containerTypes = containerTypes
      , labelPresets = labelPresets
      , form = emptyRecipeForm
      , loading = False
      , deleteConfirm = Nothing
      , showSuggestions = False
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
                    , ShowNotification { message = "Error al cargar recetas", notificationType = Error }
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
            , Cmd.none
            , NoOp
            )

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

        FormDetailsChanged details ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | details = details } }, Cmd.none, NoOp )

        SaveRecipe ->
            if String.trim model.form.name == "" then
                ( model, Cmd.none, ShowNotification { message = "El nombre es obligatorio", notificationType = Error } )

            else if List.isEmpty model.form.selectedIngredients then
                ( model, Cmd.none, ShowNotification { message = "Debes añadir al menos un ingrediente", notificationType = Error } )

            else
                ( { model | loading = True }
                , Api.saveRecipe model.form RecipeSaved
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
                    , details = Maybe.withDefault "" recipe.details
                    }
              }
            , Cmd.none
            , NoOp
            )

        CancelEdit ->
            ( { model | form = emptyRecipeForm }, Cmd.none, NoOp )

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
                    ( { model | loading = False, form = emptyRecipeForm }
                    , Api.fetchRecipes GotRecipes
                    , ShowNotification { message = "Receta guardada", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al guardar receta", notificationType = Error }
                    )

        RecipeDeleted result ->
            case result of
                Ok _ ->
                    ( { model | loading = False }
                    , Api.fetchRecipes GotRecipes
                    , ShowNotification { message = "Receta eliminada", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al eliminar receta", notificationType = Error }
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


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Recetas" ]
        , div [ class "grid grid-cols-1 md:grid-cols-2 gap-6" ]
            [ viewForm model
            , viewList model
            ]
        , viewDeleteConfirm model.deleteConfirm
        ]


viewForm : Model -> Html Msg
viewForm model =
    div [ class "card" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ]
            [ text
                (if model.form.editing /= Nothing then
                    "Editar Receta"

                 else
                    "Nueva Receta"
                )
            ]
        , Html.form [ onSubmit SaveRecipe, class "space-y-4" ]
            [ div []
                [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Nombre" ]
                , input
                    [ type_ "text"
                    , class "input-field"
                    , placeholder "Ej: Arroz con pollo"
                    , value model.form.name
                    , onInput FormNameChanged
                    , required True
                    ]
                    []
                ]
            , viewIngredientSelector model
            , div [ class "grid grid-cols-3 gap-4" ]
                [ div []
                    [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Porciones" ]
                    , input
                        [ type_ "number"
                        , class "input-field"
                        , Attr.min "1"
                        , placeholder "1"
                        , value model.form.defaultPortions
                        , onInput FormPortionsChanged
                        ]
                        []
                    ]
                , div []
                    [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Envase" ]
                    , select
                        [ class "input-field"
                        , onInput FormContainerChanged
                        , value model.form.defaultContainerId
                        ]
                        (option [ value "" ] [ text "-- Sin preferencia --" ]
                            :: List.map
                                (\cont ->
                                    option [ value cont.name, selected (cont.name == model.form.defaultContainerId) ]
                                        [ text cont.name ]
                                )
                                model.containerTypes
                        )
                    ]
                , div []
                    [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Etiqueta" ]
                    , select
                        [ class "input-field"
                        , onInput FormLabelPresetChanged
                        , value model.form.defaultLabelPreset
                        ]
                        (option [ value "" ] [ text "-- Sin preferencia --" ]
                            :: List.map
                                (\preset ->
                                    option [ value preset.name, selected (preset.name == model.form.defaultLabelPreset) ]
                                        [ text preset.name ]
                                )
                                model.labelPresets
                        )
                    ]
                ]
            , div []
                [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Detalles (opcional)" ]
                , textarea
                    [ class "input-field font-mono text-sm"
                    , placeholder "Notas adicionales en formato Markdown.\nEj: ## Preparación\n1. Descongelar\n2. Calentar"
                    , value model.form.details
                    , onInput FormDetailsChanged
                    , Attr.rows 4
                    ]
                    []
                , p [ class "text-xs text-gray-500 mt-1" ] [ text "Se mostrará al escanear el QR de la porción." ]
                ]
            , div [ class "flex justify-end space-x-4 pt-4" ]
                [ if model.form.editing /= Nothing then
                    button
                        [ type_ "button"
                        , class "px-4 py-2 bg-gray-500 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors"
                        , onClick CancelEdit
                        ]
                        [ text "Cancelar" ]

                  else
                    text ""
                , button
                    [ type_ "submit"
                    , class "btn-primary"
                    , disabled model.loading
                    ]
                    [ if model.loading then
                        text "Guardando..."

                      else
                        text "Guardar"
                    ]
                ]
            ]
        ]


viewIngredientSelector : Model -> Html Msg
viewIngredientSelector model =
    let
        inputValue =
            model.form.ingredientInput

        filteredSuggestions =
            if String.length inputValue >= 1 then
                model.ingredients
                    |> List.filter
                        (\ing ->
                            String.contains (String.toLower inputValue) (String.toLower ing.name)
                                && not (List.any (\sel -> String.toLower sel.name == String.toLower ing.name) model.form.selectedIngredients)
                        )
                    |> List.take 5

            else
                []

        showNewOption =
            inputValue
                /= ""
                && not (List.any (\ing -> String.toLower ing.name == String.toLower (String.trim inputValue)) model.ingredients)
                && not (List.any (\sel -> String.toLower sel.name == String.toLower (String.trim inputValue)) model.form.selectedIngredients)
    in
    div []
        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Ingredientes" ]
        , if not (List.isEmpty model.form.selectedIngredients) then
            div [ class "flex flex-wrap gap-2 mb-2" ]
                (List.map viewIngredientChip model.form.selectedIngredients)

          else
            p [ class "text-xs text-gray-500 mb-2" ] [ text "Pulsa Enter o coma para añadir. Los nuevos ingredientes se crearán automáticamente." ]
        , div [ class "relative" ]
            [ input
                [ type_ "text"
                , class "input-field"
                , placeholder "Escribe para buscar o añadir ingredientes..."
                , value inputValue
                , onInput FormIngredientInputChanged
                , onKeyDown IngredientKeyDown
                , Attr.autocomplete False
                , id "recipe-ingredient-input"
                ]
                []
            , if model.showSuggestions && (not (List.isEmpty filteredSuggestions) || showNewOption) then
                div [ class "absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-48 overflow-y-auto" ]
                    (List.map viewSuggestion filteredSuggestions
                        ++ (if showNewOption then
                                [ viewNewIngredientOption (String.trim inputValue) ]

                            else
                                []
                           )
                    )

              else
                text ""
            ]
        ]


viewSuggestion : Ingredient -> Html Msg
viewSuggestion ingredient =
    button
        [ type_ "button"
        , class "w-full text-left px-4 py-2 hover:bg-frost-50 flex justify-between items-center"
        , onClick (AddIngredient ingredient.name)
        ]
        [ span [ class "font-medium" ] [ text ingredient.name ]
        , span [ class "text-xs text-gray-500" ]
            [ text
                (case ingredient.expireDays of
                    Just days ->
                        String.fromInt days ++ " días"

                    Nothing ->
                        "sin caducidad"
                )
            ]
        ]


viewNewIngredientOption : String -> Html Msg
viewNewIngredientOption name =
    button
        [ type_ "button"
        , class "w-full text-left px-4 py-2 hover:bg-green-50 border-t border-gray-200 flex items-center"
        , onClick (AddIngredient name)
        ]
        [ span [ class "text-green-600 mr-2" ] [ text "+" ]
        , span [ class "font-medium" ] [ text name ]
        , span [ class "ml-2 text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded" ] [ text "nuevo" ]
        ]


viewIngredientChip : SelectedIngredient -> Html Msg
viewIngredientChip ingredient =
    let
        chipClass =
            if ingredient.isNew then
                "inline-flex items-center px-3 py-1 rounded-full text-sm bg-green-100 text-green-800"

            else
                "inline-flex items-center px-3 py-1 rounded-full text-sm bg-frost-100 text-frost-800"
    in
    span [ class chipClass ]
        [ text ingredient.name
        , if ingredient.isNew then
            span [ class "ml-1 text-xs text-green-600" ] [ text "(nuevo)" ]

          else
            text ""
        , button
            [ type_ "button"
            , class "ml-2 text-gray-500 hover:text-gray-700"
            , onClick (RemoveIngredient ingredient.name)
            ]
            [ text "×" ]
        ]


viewList : Model -> Html Msg
viewList model =
    div [ class "card" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ] [ text "Recetas existentes" ]
        , if List.isEmpty model.recipes then
            div [ class "text-center py-8 text-gray-500" ]
                [ text "No hay recetas definidas" ]

          else
            div [ class "overflow-x-auto" ]
                [ table [ class "w-full" ]
                    [ thead [ class "bg-gray-50" ]
                        [ tr []
                            [ th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Nombre" ]
                            , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Ingredientes" ]
                            , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Porciones" ]
                            , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Acciones" ]
                            ]
                        ]
                    , tbody [ class "divide-y divide-gray-200" ]
                        (List.map viewRow model.recipes)
                    ]
                ]
        ]


viewRow : Recipe -> Html Msg
viewRow recipe =
    tr [ class "hover:bg-gray-50" ]
        [ td [ class "px-4 py-3 font-medium text-gray-900" ] [ text recipe.name ]
        , td [ class "px-4 py-3 text-gray-600 text-sm" ]
            [ text
                (if String.length recipe.ingredients > 40 then
                    String.left 40 recipe.ingredients ++ "..."

                 else
                    recipe.ingredients
                )
            ]
        , td [ class "px-4 py-3 text-gray-600" ] [ text (String.fromInt recipe.defaultPortions) ]
        , td [ class "px-4 py-3" ]
            [ div [ class "flex space-x-2" ]
                [ button
                    [ onClick (EditRecipe recipe)
                    , class "text-blue-600 hover:text-blue-800 font-medium text-sm"
                    , title "Editar"
                    ]
                    [ text "✏️" ]
                , button
                    [ onClick (DeleteRecipe recipe.name)
                    , class "text-red-600 hover:text-red-800 font-medium text-sm"
                    , title "Eliminar"
                    ]
                    [ text "🗑️" ]
                ]
            ]
        ]


viewDeleteConfirm : Maybe String -> Html Msg
viewDeleteConfirm maybeName =
    case maybeName of
        Just name ->
            div [ class "fixed inset-0 z-50 flex items-center justify-center" ]
                [ div
                    [ class "absolute inset-0 bg-black bg-opacity-50"
                    , onClick CancelDelete
                    ]
                    []
                , div [ class "relative bg-white rounded-xl shadow-2xl max-w-md w-full mx-4 overflow-hidden" ]
                    [ div [ class "px-6 py-4 border-b" ]
                        [ h3 [ class "text-lg font-semibold text-gray-800" ]
                            [ text "Confirmar eliminación" ]
                        ]
                    , div [ class "p-6" ]
                        [ p [ class "text-gray-600" ]
                            [ text "¿Estás seguro de que quieres eliminar la receta \""
                            , span [ class "font-medium" ] [ text name ]
                            , text "\"? Esta acción no se puede deshacer."
                            ]
                        ]
                    , div [ class "flex justify-end px-6 py-4 bg-gray-50 border-t space-x-4" ]
                        [ button
                            [ onClick CancelDelete
                            , class "px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-medium"
                            ]
                            [ text "Cancelar" ]
                        , button
                            [ onClick (ConfirmDelete name)
                            , class "px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium"
                            ]
                            [ text "Eliminar" ]
                        ]
                    ]
                ]

        Nothing ->
            text ""


onKeyDown : (String -> msg) -> Html.Attribute msg
onKeyDown toMsg =
    Html.Events.preventDefaultOn "keydown"
        (Decode.field "key" Decode.string
            |> Decode.map
                (\key ->
                    if key == "Enter" || key == "," then
                        ( toMsg key, True )

                    else
                        ( toMsg key, False )
                )
        )
