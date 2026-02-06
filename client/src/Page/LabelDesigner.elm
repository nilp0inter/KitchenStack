module Page.LabelDesigner exposing
    ( Model
    , Msg
    , OutMsg(..)
    , init
    , update
    , view
    )

{-| Label Designer page for managing label presets with live preview.
-}

import Api
import Html exposing (..)
import Html.Attributes as Attr exposing (checked, class, disabled, placeholder, required, title, type_, value)
import Html.Events exposing (onCheck, onClick, onInput, onSubmit)
import Http
import Label
import Types exposing (..)


type alias Model =
    { presets : List LabelPreset
    , form : LabelPresetForm
    , appHost : String
    , loading : Bool
    , deleteConfirm : Maybe String
    }


type Msg
    = GotPresets (Result Http.Error (List LabelPreset))
    | FormNameChanged String
    | FormWidthChanged String
    | FormHeightChanged String
    | FormQrSizeChanged String
    | FormPaddingChanged String
    | FormTitleFontSizeChanged String
    | FormDateFontSizeChanged String
    | FormSmallFontSizeChanged String
    | FormFontFamilyChanged String
    | FormShowTitleChanged Bool
    | FormShowIngredientsChanged Bool
    | FormShowExpiryDateChanged Bool
    | FormShowBestBeforeChanged Bool
    | FormShowQrChanged Bool
    | FormShowBrandingChanged Bool
    | FormVerticalSpacingChanged String
    | FormShowSeparatorChanged Bool
    | FormSeparatorThicknessChanged String
    | FormSeparatorColorChanged String
    | FormCornerRadiusChanged String
    | FormTitleMaxCharsChanged String
    | FormIngredientsMaxCharsChanged String
    | SavePreset
    | EditPreset LabelPreset
    | CancelEdit
    | DeletePreset String
    | ConfirmDelete String
    | CancelDelete
    | PresetSaved (Result Http.Error ())
    | PresetDeleted (Result Http.Error ())
    | ApplyTemplate62mm
    | ApplyTemplate29mm
    | ApplyTemplate12mm


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshPresets


init : String -> List LabelPreset -> ( Model, Cmd Msg )
init appHost presets =
    ( { presets = presets
      , form = emptyLabelPresetForm
      , appHost = appHost
      , loading = False
      , deleteConfirm = Nothing
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotPresets result ->
            case result of
                Ok presets ->
                    ( { model | presets = presets, loading = False }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al cargar presets", notificationType = Error }
                    )

        FormNameChanged name ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | name = name } }, Cmd.none, NoOp )

        FormWidthChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | width = val } }, Cmd.none, NoOp )

        FormHeightChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | height = val } }, Cmd.none, NoOp )

        FormQrSizeChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | qrSize = val } }, Cmd.none, NoOp )

        FormPaddingChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | padding = val } }, Cmd.none, NoOp )

        FormTitleFontSizeChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | titleFontSize = val } }, Cmd.none, NoOp )

        FormDateFontSizeChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | dateFontSize = val } }, Cmd.none, NoOp )

        FormSmallFontSizeChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | smallFontSize = val } }, Cmd.none, NoOp )

        FormFontFamilyChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | fontFamily = val } }, Cmd.none, NoOp )

        FormShowTitleChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showTitle = val } }, Cmd.none, NoOp )

        FormShowIngredientsChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showIngredients = val } }, Cmd.none, NoOp )

        FormShowExpiryDateChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showExpiryDate = val } }, Cmd.none, NoOp )

        FormShowBestBeforeChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showBestBefore = val } }, Cmd.none, NoOp )

        FormShowQrChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showQr = val } }, Cmd.none, NoOp )

        FormShowBrandingChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showBranding = val } }, Cmd.none, NoOp )

        FormVerticalSpacingChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | verticalSpacing = val } }, Cmd.none, NoOp )

        FormShowSeparatorChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showSeparator = val } }, Cmd.none, NoOp )

        FormSeparatorThicknessChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | separatorThickness = val } }, Cmd.none, NoOp )

        FormSeparatorColorChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | separatorColor = val } }, Cmd.none, NoOp )

        FormCornerRadiusChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | cornerRadius = val } }, Cmd.none, NoOp )

        FormTitleMaxCharsChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | titleMaxChars = val } }, Cmd.none, NoOp )

        FormIngredientsMaxCharsChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | ingredientsMaxChars = val } }, Cmd.none, NoOp )

        SavePreset ->
            if String.isEmpty model.form.name then
                ( model
                , Cmd.none
                , ShowNotification { message = "El nombre es requerido", notificationType = Error }
                )

            else
                ( { model | loading = True }
                , Api.saveLabelPreset model.form PresetSaved
                , NoOp
                )

        EditPreset preset ->
            ( { model
                | form =
                    { name = preset.name
                    , width = String.fromInt preset.width
                    , height = String.fromInt preset.height
                    , qrSize = String.fromInt preset.qrSize
                    , padding = String.fromInt preset.padding
                    , titleFontSize = String.fromInt preset.titleFontSize
                    , dateFontSize = String.fromInt preset.dateFontSize
                    , smallFontSize = String.fromInt preset.smallFontSize
                    , fontFamily = preset.fontFamily
                    , showTitle = preset.showTitle
                    , showIngredients = preset.showIngredients
                    , showExpiryDate = preset.showExpiryDate
                    , showBestBefore = preset.showBestBefore
                    , showQr = preset.showQr
                    , showBranding = preset.showBranding
                    , verticalSpacing = String.fromInt preset.verticalSpacing
                    , showSeparator = preset.showSeparator
                    , separatorThickness = String.fromInt preset.separatorThickness
                    , separatorColor = preset.separatorColor
                    , cornerRadius = String.fromInt preset.cornerRadius
                    , titleMaxChars = String.fromInt preset.titleMaxChars
                    , ingredientsMaxChars = String.fromInt preset.ingredientsMaxChars
                    , editing = Just preset.name
                    }
              }
            , Cmd.none
            , NoOp
            )

        CancelEdit ->
            ( { model | form = emptyLabelPresetForm }, Cmd.none, NoOp )

        DeletePreset name ->
            ( { model | deleteConfirm = Just name }, Cmd.none, NoOp )

        ConfirmDelete name ->
            ( { model | deleteConfirm = Nothing, loading = True }
            , Api.deleteLabelPreset name PresetDeleted
            , NoOp
            )

        CancelDelete ->
            ( { model | deleteConfirm = Nothing }, Cmd.none, NoOp )

        PresetSaved result ->
            case result of
                Ok _ ->
                    ( { model | loading = False, form = emptyLabelPresetForm }
                    , Api.fetchLabelPresets GotPresets
                    , ShowNotification { message = "Preset guardado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al guardar preset", notificationType = Error }
                    )

        PresetDeleted result ->
            case result of
                Ok _ ->
                    ( { model | loading = False }
                    , Api.fetchLabelPresets GotPresets
                    , ShowNotification { message = "Preset eliminado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al eliminar preset", notificationType = Error }
                    )

        ApplyTemplate62mm ->
            let
                form =
                    model.form
            in
            ( { model
                | form =
                    { form
                        | width = "696"
                        , height = "300"
                        , qrSize = "200"
                        , padding = "20"
                        , titleFontSize = "48"
                        , dateFontSize = "32"
                        , smallFontSize = "18"
                        , fontFamily = "sans-serif"
                        , showTitle = True
                        , showIngredients = False
                        , showExpiryDate = True
                        , showBestBefore = False
                        , showQr = True
                        , showBranding = True
                        , verticalSpacing = "10"
                        , showSeparator = True
                        , separatorThickness = "1"
                        , separatorColor = "#cccccc"
                        , cornerRadius = "0"
                        , titleMaxChars = "18"
                        , ingredientsMaxChars = "45"
                    }
              }
            , Cmd.none
            , NoOp
            )

        ApplyTemplate29mm ->
            let
                form =
                    model.form
            in
            ( { model
                | form =
                    { form
                        | width = "306"
                        , height = "200"
                        , qrSize = "120"
                        , padding = "10"
                        , titleFontSize = "24"
                        , dateFontSize = "18"
                        , smallFontSize = "12"
                        , fontFamily = "sans-serif"
                        , showTitle = True
                        , showIngredients = False
                        , showExpiryDate = True
                        , showBestBefore = False
                        , showQr = True
                        , showBranding = True
                        , verticalSpacing = "6"
                        , showSeparator = True
                        , separatorThickness = "1"
                        , separatorColor = "#cccccc"
                        , cornerRadius = "0"
                        , titleMaxChars = "12"
                        , ingredientsMaxChars = "30"
                    }
              }
            , Cmd.none
            , NoOp
            )

        ApplyTemplate12mm ->
            let
                form =
                    model.form
            in
            ( { model
                | form =
                    { form
                        | width = "106"
                        , height = "100"
                        , qrSize = "60"
                        , padding = "5"
                        , titleFontSize = "14"
                        , dateFontSize = "12"
                        , smallFontSize = "8"
                        , fontFamily = "sans-serif"
                        , showTitle = True
                        , showIngredients = False
                        , showExpiryDate = True
                        , showBestBefore = False
                        , showQr = True
                        , showBranding = False
                        , verticalSpacing = "3"
                        , showSeparator = False
                        , separatorThickness = "1"
                        , separatorColor = "#cccccc"
                        , cornerRadius = "0"
                        , titleMaxChars = "8"
                        , ingredientsMaxChars = "20"
                    }
              }
            , Cmd.none
            , NoOp
            )


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Diseñador de Etiquetas" ]
        , div [ class "grid grid-cols-1 lg:grid-cols-2 gap-6" ]
            [ div [ class "space-y-6" ]
                [ viewForm model
                , viewList model
                ]
            , viewPreview model
            ]
        , viewDeleteConfirm model.deleteConfirm
        ]


viewForm : Model -> Html Msg
viewForm model =
    div [ class "card" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ]
            [ text
                (if model.form.editing /= Nothing then
                    "Editar Preset"

                 else
                    "Nuevo Preset"
                )
            ]
        , div [ class "mb-4" ]
            [ p [ class "text-sm text-gray-600 mb-2" ] [ text "Plantillas:" ]
            , div [ class "flex flex-wrap gap-2" ]
                [ button
                    [ type_ "button"
                    , class "px-3 py-1 text-sm bg-frost-100 hover:bg-frost-200 text-frost-700 rounded-lg"
                    , onClick ApplyTemplate62mm
                    ]
                    [ text "62mm" ]
                , button
                    [ type_ "button"
                    , class "px-3 py-1 text-sm bg-frost-100 hover:bg-frost-200 text-frost-700 rounded-lg"
                    , onClick ApplyTemplate29mm
                    ]
                    [ text "29mm" ]
                , button
                    [ type_ "button"
                    , class "px-3 py-1 text-sm bg-frost-100 hover:bg-frost-200 text-frost-700 rounded-lg"
                    , onClick ApplyTemplate12mm
                    ]
                    [ text "12mm" ]
                ]
            ]
        , Html.form [ onSubmit SavePreset, class "space-y-4" ]
            [ -- Name field
              div []
                [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Nombre" ]
                , input
                    [ type_ "text"
                    , class "input-field"
                    , placeholder "Ej: Mi etiqueta personalizada"
                    , value model.form.name
                    , onInput FormNameChanged
                    , required True
                    , disabled (model.form.editing /= Nothing)
                    ]
                    []
                ]

            -- Dimensions section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Dimensiones" ]
                , div [ class "grid grid-cols-2 gap-3" ]
                    [ div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Ancho (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "100"
                            , value model.form.width
                            , onInput FormWidthChanged
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Alto (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "50"
                            , value model.form.height
                            , onInput FormHeightChanged
                            ]
                            []
                        ]
                    ]
                , div [ class "grid grid-cols-2 gap-3 mt-2" ]
                    [ div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Tamaño QR (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "30"
                            , value model.form.qrSize
                            , onInput FormQrSizeChanged
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Padding (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "0"
                            , value model.form.padding
                            , onInput FormPaddingChanged
                            ]
                            []
                        ]
                    ]
                ]

            -- Font section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Fuentes" ]
                , div [ class "grid grid-cols-3 gap-3" ]
                    [ div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Título (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "8"
                            , value model.form.titleFontSize
                            , onInput FormTitleFontSizeChanged
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Fecha (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "8"
                            , value model.form.dateFontSize
                            , onInput FormDateFontSizeChanged
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Pequeña (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "6"
                            , value model.form.smallFontSize
                            , onInput FormSmallFontSizeChanged
                            ]
                            []
                        ]
                    ]
                , div [ class "mt-2" ]
                    [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Familia de fuente" ]
                    , input
                        [ type_ "text"
                        , class "input-field"
                        , placeholder "sans-serif"
                        , value model.form.fontFamily
                        , onInput FormFontFamilyChanged
                        ]
                        []
                    ]
                ]

            -- Field visibility section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Campos visibles" ]
                , div [ class "grid grid-cols-2 gap-2" ]
                    [ viewCheckbox "Título" model.form.showTitle FormShowTitleChanged
                    , viewCheckbox "Ingredientes" model.form.showIngredients FormShowIngredientsChanged
                    , viewCheckbox "Fecha caducidad" model.form.showExpiryDate FormShowExpiryDateChanged
                    , viewCheckbox "Consumo preferente" model.form.showBestBefore FormShowBestBeforeChanged
                    , viewCheckbox "Código QR" model.form.showQr FormShowQrChanged
                    , viewCheckbox "Marca FrostByte" model.form.showBranding FormShowBrandingChanged
                    ]
                ]

            -- Truncation section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Truncado de texto" ]
                , div [ class "grid grid-cols-2 gap-3" ]
                    [ div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Máx. caracteres título" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "5"
                            , value model.form.titleMaxChars
                            , onInput FormTitleMaxCharsChanged
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Máx. caracteres ingredientes" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "10"
                            , value model.form.ingredientsMaxChars
                            , onInput FormIngredientsMaxCharsChanged
                            ]
                            []
                        ]
                    ]
                ]

            -- Layout section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Diseño" ]
                , div [ class "space-y-3" ]
                    [ div [ class "grid grid-cols-2 gap-3" ]
                        [ div []
                            [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Espaciado vertical (px)" ]
                            , input
                                [ type_ "number"
                                , class "input-field"
                                , Attr.min "0"
                                , value model.form.verticalSpacing
                                , onInput FormVerticalSpacingChanged
                                ]
                                []
                            ]
                        , div []
                            [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Radio esquinas (px)" ]
                            , input
                                [ type_ "number"
                                , class "input-field"
                                , Attr.min "0"
                                , value model.form.cornerRadius
                                , onInput FormCornerRadiusChanged
                                , title "Solo afecta la vista previa"
                                ]
                                []
                            ]
                        ]
                    , viewCheckbox "Línea separadora" model.form.showSeparator FormShowSeparatorChanged
                    , if model.form.showSeparator then
                        div [ class "grid grid-cols-2 gap-3 ml-6" ]
                            [ div []
                                [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Grosor (px)" ]
                                , input
                                    [ type_ "number"
                                    , class "input-field"
                                    , Attr.min "1"
                                    , value model.form.separatorThickness
                                    , onInput FormSeparatorThicknessChanged
                                    ]
                                    []
                                ]
                            , div []
                                [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Color" ]
                                , input
                                    [ type_ "color"
                                    , class "input-field h-10"
                                    , value model.form.separatorColor
                                    , onInput FormSeparatorColorChanged
                                    ]
                                    []
                                ]
                            ]

                      else
                        text ""
                    ]
                ]

            -- Submit buttons
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


viewCheckbox : String -> Bool -> (Bool -> Msg) -> Html Msg
viewCheckbox labelText isChecked onChange =
    label [ class "flex items-center space-x-2 cursor-pointer" ]
        [ input
            [ type_ "checkbox"
            , class "w-4 h-4 text-frost-600 rounded border-gray-300 focus:ring-frost-500"
            , checked isChecked
            , onCheck onChange
            ]
            []
        , span [ class "text-sm text-gray-700" ] [ text labelText ]
        ]


viewPreview : Model -> Html Msg
viewPreview model =
    let
        settings =
            formToSettings model.form

        sampleData =
            { portionId = "sample-preview"
            , name = "Pollo con arroz"
            , ingredients = "pollo, arroz, verduras, cebolla, ajo"
            , expiryDate = "2025-12-31"
            , bestBeforeDate = Just "2025-12-25"
            , appHost = model.appHost
            }

        -- Scale preview to fit card
        previewScale =
            min 1.0 (500 / toFloat settings.width)
    in
    div [ class "card sticky top-4" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ] [ text "Vista Previa" ]
        , div [ class "flex justify-center items-center bg-gray-100 rounded-lg p-4 overflow-auto min-h-[200px]" ]
            [ div
                [ Attr.style "transform" ("scale(" ++ String.fromFloat previewScale ++ ")")
                , Attr.style "transform-origin" "center center"
                ]
                [ Label.viewLabel settings sampleData ]
            ]
        , div [ class "mt-4 text-center text-sm text-gray-500" ]
            [ text (String.fromInt settings.width ++ " x " ++ String.fromInt settings.height ++ " px")
            , if settings.cornerRadius > 0 then
                span [ class "ml-2 text-xs text-gray-400" ] [ text "(radio de esquinas solo en vista previa)" ]

              else
                text ""
            ]
        ]


viewList : Model -> Html Msg
viewList model =
    div [ class "card" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ] [ text "Presets existentes" ]
        , if List.isEmpty model.presets then
            div [ class "text-center py-8 text-gray-500" ]
                [ text "No hay presets definidos" ]

          else
            div [ class "space-y-2" ]
                (List.map viewPresetRow model.presets)
        ]


viewPresetRow : LabelPreset -> Html Msg
viewPresetRow preset =
    div [ class "flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100" ]
        [ div []
            [ div [ class "font-medium text-gray-900" ] [ text preset.name ]
            , div [ class "text-sm text-gray-500" ]
                [ text (String.fromInt preset.width ++ "x" ++ String.fromInt preset.height ++ " px") ]
            ]
        , div [ class "flex space-x-2" ]
            [ button
                [ onClick (EditPreset preset)
                , class "text-blue-600 hover:text-blue-800 font-medium text-sm"
                , title "Editar"
                ]
                [ text "Editar" ]
            , button
                [ onClick (DeletePreset preset.name)
                , class "text-red-600 hover:text-red-800 font-medium text-sm"
                , title "Eliminar"
                ]
                [ text "Eliminar" ]
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
                            [ text "¿Estás seguro de que quieres eliminar el preset \""
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


{-| Convert form values to LabelSettings for preview.
-}
formToSettings : LabelPresetForm -> Label.LabelSettings
formToSettings form =
    { name = form.name
    , width = Maybe.withDefault 696 (String.toInt form.width)
    , height = Maybe.withDefault 300 (String.toInt form.height)
    , qrSize = Maybe.withDefault 200 (String.toInt form.qrSize)
    , padding = Maybe.withDefault 20 (String.toInt form.padding)
    , titleFontSize = Maybe.withDefault 48 (String.toInt form.titleFontSize)
    , dateFontSize = Maybe.withDefault 32 (String.toInt form.dateFontSize)
    , smallFontSize = Maybe.withDefault 18 (String.toInt form.smallFontSize)
    , fontFamily = form.fontFamily
    , showTitle = form.showTitle
    , showIngredients = form.showIngredients
    , showExpiryDate = form.showExpiryDate
    , showBestBefore = form.showBestBefore
    , showQr = form.showQr
    , showBranding = form.showBranding
    , verticalSpacing = Maybe.withDefault 10 (String.toInt form.verticalSpacing)
    , showSeparator = form.showSeparator
    , separatorThickness = Maybe.withDefault 1 (String.toInt form.separatorThickness)
    , separatorColor = form.separatorColor
    , cornerRadius = Maybe.withDefault 0 (String.toInt form.cornerRadius)
    , titleMaxChars = Maybe.withDefault 18 (String.toInt form.titleMaxChars)
    , ingredientsMaxChars = Maybe.withDefault 45 (String.toInt form.ingredientsMaxChars)
    }
