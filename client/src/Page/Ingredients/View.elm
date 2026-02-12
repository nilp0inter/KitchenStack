module Page.Ingredients.View exposing (view)

import Html exposing (..)
import Html.Attributes as Attr exposing (class, disabled, placeholder, required, title, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Page.Ingredients.Types exposing (..)
import Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Ingredientes" ]
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
            [ h2 [ class "text-lg font-semibold text-gray-800" ] [ text "Ingredientes existentes" ]
            , button
                [ class "btn-primary"
                , onClick StartCreate
                ]
                [ text "+ Nuevo Ingrediente" ]
            ]
        , if List.isEmpty model.ingredients then
            div [ class "text-center py-8 text-gray-500" ]
                [ text "No hay ingredientes definidos" ]

          else
            div [ class "overflow-x-auto" ]
                [ table [ class "w-full" ]
                    [ thead [ class "bg-gray-50" ]
                        [ tr []
                            [ th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Nombre" ]
                            , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Caduca (días)" ]
                            , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Consumo pref." ]
                            , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Acciones" ]
                            ]
                        ]
                    , tbody [ class "divide-y divide-gray-200" ]
                        (List.map viewRow model.ingredients)
                    ]
                ]
        ]


viewForm : Model -> Html Msg
viewForm model =
    div [ class "card" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ]
            [ text
                (if model.form.editing /= Nothing then
                    "Editar Ingrediente"

                 else
                    "Nuevo Ingrediente"
                )
            ]
        , Html.form [ onSubmit SaveIngredient, class "space-y-4" ]
            [ div []
                [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Nombre" ]
                , input
                    [ type_ "text"
                    , class "input-field"
                    , placeholder "Ej: pollo"
                    , value model.form.name
                    , onInput FormNameChanged
                    , required True
                    , disabled (model.form.editing /= Nothing)
                    ]
                    []
                , p [ class "text-xs text-gray-500 mt-1" ] [ text "El nombre se guardará en minúsculas" ]
                ]
            , div []
                [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Días hasta caducidad" ]
                , input
                    [ type_ "number"
                    , class "input-field"
                    , Attr.min "1"
                    , placeholder "Ej: 365"
                    , value model.form.expireDays
                    , onInput FormExpireDaysChanged
                    ]
                    []
                , p [ class "text-xs text-gray-500 mt-1" ] [ text "Días hasta que no es seguro consumir (opcional)" ]
                ]
            , div []
                [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Días hasta consumo preferente" ]
                , input
                    [ type_ "number"
                    , class "input-field"
                    , Attr.min "1"
                    , placeholder "Ej: 270"
                    , value model.form.bestBeforeDays
                    , onInput FormBestBeforeDaysChanged
                    ]
                    []
                , p [ class "text-xs text-gray-500 mt-1" ] [ text "Días hasta que la calidad se degrada (opcional)" ]
                ]
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


viewRow : Ingredient -> Html Msg
viewRow ingredient =
    tr [ class "hover:bg-gray-50" ]
        [ td [ class "px-4 py-3 font-medium text-gray-900" ] [ text ingredient.name ]
        , td [ class "px-4 py-3 text-gray-600" ]
            [ text (Maybe.withDefault "-" (Maybe.map String.fromInt ingredient.expireDays)) ]
        , td [ class "px-4 py-3 text-gray-600" ]
            [ text (Maybe.withDefault "-" (Maybe.map String.fromInt ingredient.bestBeforeDays)) ]
        , td [ class "px-4 py-3" ]
            [ div [ class "flex space-x-2" ]
                [ button
                    [ onClick (EditIngredient ingredient)
                    , class "text-blue-600 hover:text-blue-800 font-medium text-sm"
                    , title "Editar"
                    ]
                    [ text "✏️" ]
                , button
                    [ onClick (DeleteIngredient ingredient.name)
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
                            [ text "¿Estás seguro de que quieres eliminar el ingrediente \""
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
