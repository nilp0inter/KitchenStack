module Page.NewBatch.View exposing (view)

import Components.MarkdownEditor as MarkdownEditor
import Data.LabelPreset
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes as Attr exposing (alt, class, disabled, href, id, placeholder, required, selected, src, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Json.Decode as Decode
import Label
import Page.NewBatch.Types exposing (..)
import Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Añadir Nuevas Porciones" ]
        , div [ class "card" ]
            [ Html.form [ onSubmit SubmitBatchWithPrint, class "space-y-6" ]
                [ div []
                    [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Nombre" ]
                    , div [ class "relative" ]
                        [ input
                            [ type_ "text"
                            , class "input-field"
                            , placeholder "Ej: Arroz con pollo"
                            , value model.form.name
                            , onInput FormNameChanged
                            , required True
                            ]
                            []
                        , viewRecipeSuggestions model
                        ]
                    ]
                , viewIngredientSelector model
                , div [ class "grid grid-cols-2 gap-4" ]
                    [ div []
                        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Tipo de Envase" ]
                        , select
                            [ class "input-field"
                            , onInput FormContainerChanged
                            , value model.form.containerId
                            ]
                            (List.map
                                (\cont ->
                                    option [ value cont.name, selected (cont.name == model.form.containerId) ]
                                        [ text cont.name ]
                                )
                                model.containerTypes
                            )
                        ]
                    , div []
                        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Cantidad de Porciones" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "1"
                            , value model.form.quantity
                            , onInput FormQuantityChanged
                            , required True
                            ]
                            []
                        , p [ class "text-xs text-gray-500 mt-1" ] [ text "Se imprimirá una etiqueta por cada porción" ]
                        ]
                    ]
                , div [ class "grid grid-cols-2 gap-4" ]
                    [ div []
                        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Fecha de Congelación" ]
                        , input
                            [ type_ "date"
                            , class "input-field"
                            , value model.form.createdAt
                            , onInput FormCreatedAtChanged
                            , required True
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ]
                            [ text
                                (if model.expiryRequired then
                                    "Fecha de Caducidad (obligatoria)"

                                 else
                                    "Fecha de Caducidad (opcional)"
                                )
                            ]
                        , input
                            [ type_ "date"
                            , class
                                (if model.expiryRequired then
                                    "input-field border-orange-400"

                                 else
                                    "input-field"
                                )
                            , value model.form.expiryDate
                            , onInput FormExpiryDateChanged
                            , required model.expiryRequired
                            ]
                            []
                        , p [ class "text-xs text-gray-500 mt-1" ]
                            [ text
                                (if model.expiryRequired then
                                    "Obligatoria: ningún ingrediente tiene días de caducidad"

                                 else
                                    "Se calculará automáticamente si se deja en blanco"
                                )
                            ]
                        ]
                    ]
                , viewPresetSelector model
                , viewImageSelector model.form.image
                , Html.map DetailsEditorMsg (MarkdownEditor.view model.detailsEditor)
                , div [ class "flex justify-end space-x-4 pt-4" ]
                    [ a [ href "/", class "btn-secondary" ] [ text "Cancelar" ]
                    , button
                        [ type_ "button"
                        , class "px-6 py-2 bg-gray-500 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors"
                        , disabled model.loading
                        , onClick SubmitBatchOnly
                        ]
                        [ if model.loading then
                            text "Guardando..."

                          else
                            text "Guardar"
                        ]
                    , button
                        [ type_ "submit"
                        , class "btn-primary"
                        , disabled model.loading
                        ]
                        [ if model.loading then
                            text "Guardando..."

                          else
                            text "Guardar e Imprimir"
                        ]
                    ]
                ]
            ]
        , viewHiddenLabels model
        ]


viewPresetSelector : Model -> Html Msg
viewPresetSelector model =
    div []
        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Tamaño de Etiqueta" ]
        , select
            [ class "input-field"
            , onInput SelectPreset
            , value (Maybe.map .name model.selectedPreset |> Maybe.withDefault "")
            ]
            (List.map
                (\preset ->
                    option
                        [ value preset.name
                        , selected (Maybe.map .name model.selectedPreset == Just preset.name)
                        ]
                        [ text (preset.name ++ " (" ++ String.fromInt preset.width ++ "×" ++ String.fromInt preset.height ++ ")") ]
                )
                model.labelPresets
            )
        ]


{-| Render hidden SVG labels for pending print jobs.
These are rendered off-screen and used for SVG→PNG conversion.
Uses computed label data for dynamic font sizing and text wrapping.
-}
viewHiddenLabels : Model -> Html Msg
viewHiddenLabels model =
    case model.selectedPreset of
        Just preset ->
            let
                labelSettings =
                    Data.LabelPreset.presetToSettings preset

                -- Default computed data when measurement hasn't completed yet
                defaultComputed =
                    { titleFontSize = preset.titleFontSize
                    , ingredientLines = []
                    }
            in
            div
                [ Attr.style "position" "absolute"
                , Attr.style "left" "-9999px"
                , Attr.style "top" "-9999px"
                ]
                (List.filterMap
                    (\printData ->
                        -- Only render labels that have computed data
                        case Dict.get printData.portionId model.computedLabelData of
                            Just computed ->
                                Just
                                    (Label.viewLabelWithComputed labelSettings
                                        { portionId = printData.portionId
                                        , name = printData.name
                                        , ingredients = printData.ingredients
                                        , expiryDate = printData.expiryDate
                                        , bestBeforeDate = printData.bestBeforeDate
                                        , appHost = model.appHost
                                        }
                                        computed
                                    )

                            Nothing ->
                                -- Label not yet measured, skip rendering
                                Nothing
                    )
                    model.pendingPrintData
                )

        Nothing ->
            text ""


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
                , id "ingredient-input"
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


viewRecipeSuggestions : Model -> Html Msg
viewRecipeSuggestions model =
    let
        searchTerm =
            String.toLower model.form.name

        matchingRecipes =
            if String.length model.form.name >= 2 then
                model.recipes
                    |> List.filter (\r -> String.contains searchTerm (String.toLower r.name))
                    |> List.take 5

            else
                []
    in
    if model.showRecipeSuggestions && not (List.isEmpty matchingRecipes) then
        div [ class "absolute z-20 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto" ]
            (List.map viewRecipeSuggestion matchingRecipes)

    else
        text ""


viewRecipeSuggestion : Recipe -> Html Msg
viewRecipeSuggestion recipe =
    button
        [ type_ "button"
        , class "w-full text-left px-4 py-3 hover:bg-frost-50 border-b border-gray-100 last:border-b-0"
        , onClick (SelectRecipe recipe)
        ]
        [ div [ class "flex items-start gap-3" ]
            [ case recipe.image of
                Just imageData ->
                    img
                        [ src imageData
                        , alt recipe.name
                        , class "w-10 h-10 object-cover rounded-lg flex-shrink-0"
                        ]
                        []

                Nothing ->
                    div [ class "w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center text-gray-400 flex-shrink-0" ]
                        [ text "📷" ]
            , div [ class "flex-1 min-w-0" ]
                [ div [ class "flex items-center justify-between" ]
                    [ span [ class "font-medium text-gray-900" ] [ text recipe.name ]
                    , span [ class "text-xs bg-frost-100 text-frost-700 px-2 py-0.5 rounded" ] [ text "Receta" ]
                    ]
                , div [ class "text-sm text-gray-500 mt-1 truncate" ]
                    [ text
                        (if String.length recipe.ingredients > 50 then
                            String.left 50 recipe.ingredients ++ "..."

                         else
                            recipe.ingredients
                        )
                    ]
                ]
            ]
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
                        , alt "Imagen del lote"
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
