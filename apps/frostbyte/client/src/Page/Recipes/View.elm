module Page.Recipes.View exposing (view)

import Components.MarkdownEditor as MarkdownEditor
import Html exposing (..)
import Html.Attributes as Attr exposing (alt, class, disabled, id, placeholder, required, selected, src, title, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Json.Decode as Decode
import Page.Recipes.Types exposing (..)
import Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Recetas" ]
        , case model.viewMode of
            Types.ListMode ->
                viewListMode model

            Types.FormMode ->
                viewForm model
        , viewDeleteConfirm model.deleteConfirm
        ]


viewListMode : Model -> Html Msg
viewListMode model =
    div [ class "card" ]
        [ div [ class "flex items-center justify-between mb-4" ]
            [ h2 [ class "text-lg font-semibold text-gray-800" ] [ text "Recetas existentes" ]
            , button
                [ class "btn-primary"
                , onClick StartCreate
                ]
                [ text "+ Nueva Receta" ]
            ]
        , if List.isEmpty model.recipes then
            div [ class "text-center py-8 text-gray-500" ]
                [ text "No hay recetas definidas" ]

          else
            div [ class "overflow-x-auto" ]
                [ table [ class "w-full" ]
                    [ thead [ class "bg-gray-50" ]
                        [ tr []
                            [ th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600 w-16" ] [ text "" ]
                            , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Nombre" ]
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
            , viewImageSelector model.form.image
            , Html.map DetailsEditorMsg (MarkdownEditor.view model.detailsEditor)
            , div [ class "flex justify-end space-x-4 pt-4" ]
                [ button
                    [ type_ "button"
                    , class "px-4 py-2 bg-gray-500 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors"
                    , onClick CancelEdit
                    ]
                    [ text "Cancelar" ]
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


viewImageSelector : Maybe String -> Html Msg
viewImageSelector maybeImage =
    div []
        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Imagen (opcional)" ]
        , case maybeImage of
            Just imageData ->
                div [ class "flex items-center gap-4" ]
                    [ img
                        [ src imageData
                        , alt "Imagen de la receta"
                        , class "w-24 h-24 object-cover rounded-lg border border-gray-200"
                        ]
                        []
                    , div [ class "flex flex-col gap-2" ]
                        [ button
                            [ type_ "button"
                            , class "px-3 py-1 bg-frost-500 hover:bg-frost-600 text-white text-sm rounded-lg transition-colors"
                            , onClick SelectImage
                            ]
                            [ text "Cambiar" ]
                        , button
                            [ type_ "button"
                            , class "px-3 py-1 bg-red-500 hover:bg-red-600 text-white text-sm rounded-lg transition-colors"
                            , onClick RemoveImage
                            ]
                            [ text "Eliminar" ]
                        ]
                    ]

            Nothing ->
                button
                    [ type_ "button"
                    , class "px-4 py-2 border-2 border-dashed border-gray-300 rounded-lg text-gray-500 hover:border-frost-400 hover:text-frost-600 transition-colors"
                    , onClick SelectImage
                    ]
                    [ text "📷 Añadir imagen" ]
        , p [ class "text-xs text-gray-500 mt-1" ] [ text "Máximo 500KB. Formatos: PNG, JPEG, WebP" ]
        ]


viewRow : Recipe -> Html Msg
viewRow recipe =
    tr [ class "hover:bg-gray-50" ]
        [ td [ class "px-4 py-3" ]
            [ case recipe.image of
                Just imageData ->
                    img
                        [ src imageData
                        , alt recipe.name
                        , class "w-12 h-12 object-cover rounded-lg"
                        ]
                        []

                Nothing ->
                    div [ class "w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center text-gray-400" ]
                        [ text "📷" ]
            ]
        , td [ class "px-4 py-3 font-medium text-gray-900" ] [ text recipe.name ]
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
