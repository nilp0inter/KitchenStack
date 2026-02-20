module Page.EditBatch.View exposing (view)

import Components
import Components.MarkdownEditor as MarkdownEditor
import Data.Label
import Data.LabelPreset
import Dict
import Html exposing (..)
import Html.Attributes as Attr exposing (alt, class, disabled, href, id, placeholder, required, selected, src, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Json.Decode as Decode
import Label
import Page.EditBatch.Types exposing (..)
import Types exposing (..)


view : Model -> Html Msg
view model =
    if model.loading then
        Components.viewLoading

    else
        case model.batch of
            Nothing ->
                div [ class "text-center py-12" ]
                    [ span [ class "text-6xl" ] [ text "?" ]
                    , h1 [ class "text-3xl font-bold text-gray-800 mt-4" ] [ text "Batch no encontrado" ]
                    , a [ href "/", class "btn-primary inline-block mt-4" ] [ text "Volver al inicio" ]
                    ]

            Just batch ->
                div []
                    [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text ("Editar: " ++ batch.name) ]
                    , div [ class "card" ]
                        [ Html.form [ onSubmit SubmitUpdateAndPrint, class "space-y-6" ]
                            [ viewNameField model
                            , viewIngredientSelector model
                            , div [ class "grid grid-cols-2 gap-4" ]
                                [ viewContainerSelector model
                                , viewBestBeforeDateField model
                                ]
                            , viewPresetSelector model
                            , viewImageSelector model.form.image
                            , Html.map DetailsEditorMsg (MarkdownEditor.view model.detailsEditor)
                            , viewExistingPortions model
                            , viewNewPortionsSection model
                            , viewSubmitButtons model
                            ]
                        ]
                    , viewHiddenLabels model
                    ]


viewNameField : Model -> Html Msg
viewNameField model =
    div []
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
            p [ class "text-xs text-gray-500 mb-2" ] [ text "Pulsa Enter o coma para añadir." ]
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
            [ text "x" ]
        ]


viewContainerSelector : Model -> Html Msg
viewContainerSelector model =
    div []
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


viewBestBeforeDateField : Model -> Html Msg
viewBestBeforeDateField model =
    div []
        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Consumo preferente (opcional)" ]
        , input
            [ type_ "date"
            , class "input-field"
            , value model.form.bestBeforeDate
            , onInput FormBestBeforeDateChanged
            ]
            []
        , p [ class "text-xs text-gray-500 mt-1" ] [ text "Se recalculará automáticamente si se deja en blanco" ]
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
                        [ text (preset.name ++ " (" ++ String.fromInt preset.width ++ "x" ++ String.fromInt preset.height ++ ")") ]
                )
                model.labelPresets
            )
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
                    [ text "Añadir imagen" ]
        , p [ class "text-xs text-gray-500 mt-1" ] [ text "Máximo 500KB. Formatos: PNG, JPEG, WebP" ]
        ]


viewExistingPortions : Model -> Html Msg
viewExistingPortions model =
    if List.isEmpty model.portions then
        text ""

    else
        div []
            [ label [ class "block text-sm font-medium text-gray-700 mb-2" ] [ text "Porciones existentes" ]
            , div [ class "border border-gray-200 rounded-lg overflow-hidden" ]
                [ table [ class "w-full" ]
                    [ thead [ class "bg-gray-50" ]
                        [ tr []
                            [ th [ class "px-3 py-2 text-left text-xs font-semibold text-gray-600" ] [ text "#" ]
                            , th [ class "px-3 py-2 text-left text-xs font-semibold text-gray-600" ] [ text "Estado" ]
                            , th [ class "px-3 py-2 text-left text-xs font-semibold text-gray-600" ] [ text "Caduca" ]
                            , th [ class "px-3 py-2 text-left text-xs font-semibold text-gray-600" ] [ text "Descartar" ]
                            ]
                        ]
                    , tbody [ class "divide-y divide-gray-200" ]
                        (List.indexedMap (viewPortionEditRow model.discardPortionIds) model.portions)
                    ]
                ]
            , if not (List.isEmpty model.discardPortionIds) then
                p [ class "text-xs text-orange-600 mt-1" ]
                    [ text (String.fromInt (List.length model.discardPortionIds) ++ " porción(es) marcada(s) para descartar") ]

              else
                text ""
            ]


viewPortionEditRow : List String -> Int -> PortionInBatch -> Html Msg
viewPortionEditRow discardIds index portion =
    let
        isDiscardMarked =
            List.member portion.portionId discardIds

        isAlreadyDiscarded =
            portion.status == "DISCARDED"

        rowClass =
            if isAlreadyDiscarded then
                "bg-gray-50 text-gray-400"

            else if isDiscardMarked then
                "bg-red-50"

            else
                ""
    in
    tr [ class rowClass ]
        [ td [ class "px-3 py-2 text-sm text-gray-600" ] [ text (String.fromInt (index + 1)) ]
        , td [ class "px-3 py-2 text-sm" ]
            [ if portion.status == "FROZEN" then
                span [ class "inline-block bg-frost-100 text-frost-700 px-2 py-0.5 rounded text-xs" ]
                    [ text "Congelada" ]

              else if portion.status == "DISCARDED" then
                span [ class "inline-block bg-gray-100 text-gray-500 px-2 py-0.5 rounded text-xs" ]
                    [ text "Descartada" ]

              else
                span [ class "inline-block bg-green-100 text-green-700 px-2 py-0.5 rounded text-xs" ]
                    [ text "Consumida" ]
            ]
        , td [ class "px-3 py-2 text-sm text-gray-600" ] [ text portion.expiryDate ]
        , td [ class "px-3 py-2" ]
            [ if isAlreadyDiscarded then
                text ""

              else
                input
                    [ type_ "checkbox"
                    , Attr.checked isDiscardMarked
                    , onClick (ToggleDiscardPortion portion.portionId)
                    , class "w-4 h-4 text-red-500 rounded"
                    ]
                    []
            ]
        ]


viewNewPortionsSection : Model -> Html Msg
viewNewPortionsSection model =
    div [ class "border-t pt-4" ]
        [ label [ class "block text-sm font-medium text-gray-700 mb-2" ] [ text "Añadir nuevas porciones" ]
        , div [ class "grid grid-cols-2 gap-4" ]
            [ div []
                [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Cantidad" ]
                , input
                    [ type_ "number"
                    , class "input-field"
                    , Attr.min "0"
                    , value model.newPortionQuantity
                    , onInput NewPortionQuantityChanged
                    ]
                    []
                ]
            , div []
                [ label [ class "block text-xs text-gray-500 mb-1" ]
                    [ text
                        (if model.expiryRequired then
                            "Caducidad nuevas (obligatoria)"

                         else
                            "Caducidad nuevas (opcional)"
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
                    , value model.newPortionsExpiryDate
                    , onInput NewPortionsExpiryDateChanged
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
        ]


viewSubmitButtons : Model -> Html Msg
viewSubmitButtons model =
    let
        newQty =
            Maybe.withDefault 0 (String.toInt model.newPortionQuantity)

        hasNewPortions =
            newQty > 0
    in
    div [ class "flex justify-end space-x-4 pt-4" ]
        [ a [ href ("/batch/" ++ model.batchId), class "btn-secondary" ] [ text "Cancelar" ]
        , button
            [ type_ "button"
            , class "px-6 py-2 bg-gray-500 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors"
            , disabled model.saving
            , onClick SubmitUpdate
            ]
            [ if model.saving then
                text "Guardando..."

              else
                text "Guardar"
            ]
        , if hasNewPortions then
            button
                [ type_ "submit"
                , class "btn-primary"
                , disabled model.saving
                ]
                [ if model.saving then
                    text "Guardando..."

                  else
                    text "Guardar e Imprimir"
                ]

          else
            text ""
        ]


viewHiddenLabels : Model -> Html Msg
viewHiddenLabels model =
    case model.selectedPreset of
        Just preset ->
            let
                labelSettings =
                    Data.LabelPreset.presetToSettings preset
            in
            div
                [ Attr.style "position" "absolute"
                , Attr.style "left" "-9999px"
                , Attr.style "top" "-9999px"
                ]
                (List.filterMap
                    (\printData ->
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
                                Nothing
                    )
                    model.pendingPrintData
                )

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
