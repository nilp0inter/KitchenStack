module Components.MarkdownEditor exposing
    ( Model
    , Msg
    , Tab(..)
    , getText
    , init
    , setText
    , update
    , view
    )

import Html exposing (..)
import Html.Attributes as Attr exposing (class, placeholder, type_, value)
import Html.Events exposing (onClick, onInput)
import Markdown.Parser
import Markdown.Renderer


type Tab
    = WriteTab
    | PreviewTab


type alias Model =
    { content : String
    , activeTab : Tab
    }


type Msg
    = ContentChanged String
    | SwitchTab Tab


init : String -> Model
init content =
    { content = content
    , activeTab = WriteTab
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        ContentChanged newContent ->
            { model | content = newContent }

        SwitchTab tab ->
            { model | activeTab = tab }


getText : Model -> String
getText model =
    model.content


setText : String -> Model -> Model
setText content model =
    { model | content = content }


view : Model -> Html Msg
view model =
    let
        parseResult =
            model.content
                |> Markdown.Parser.parse
                |> Result.mapError (\_ -> "Error de formato Markdown")
                |> Result.andThen (Markdown.Renderer.render Markdown.Renderer.defaultHtmlRenderer)

        ( indicator, indicatorClass ) =
            if String.isEmpty (String.trim model.content) then
                ( "", "" )

            else
                case parseResult of
                    Ok _ ->
                        ( " ✓", "text-green-600" )

                    Err _ ->
                        ( " ✗", "text-red-500" )
    in
    div []
        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ]
            [ text "Detalles (opcional)" ]
        , div [ class "flex border-b border-gray-200" ]
            [ tabButton "Escribir" WriteTab model.activeTab ""
            , tabButton ("Vista previa" ++ indicator) PreviewTab model.activeTab indicatorClass
            ]
        , case model.activeTab of
            WriteTab ->
                textarea
                    [ class "input-field font-mono text-sm mt-2"
                    , placeholder "Notas adicionales en formato Markdown."
                    , value model.content
                    , onInput ContentChanged
                    , Attr.rows 4
                    ]
                    []

            PreviewTab ->
                div [ class "min-h-[96px] p-3 border rounded-lg bg-gray-50 mt-2" ]
                    [ case parseResult of
                        Ok rendered ->
                            if String.isEmpty (String.trim model.content) then
                                p [ class "text-gray-400 italic" ] [ text "Sin contenido" ]

                            else
                                div [ class "prose prose-sm max-w-none text-gray-600" ] rendered

                        Err errorMsg ->
                            div [ class "text-red-600 text-sm" ] [ text errorMsg ]
                    ]
        , p [ class "text-xs text-gray-500 mt-1" ]
            [ text "Se mostrará al escanear el QR de la porción." ]
        ]


tabButton : String -> Tab -> Tab -> String -> Html Msg
tabButton labelText tab activeTab extraClass =
    let
        baseClass =
            if tab == activeTab then
                "px-4 py-2 text-frost-600 border-b-2 border-frost-600 font-medium -mb-px"

            else
                "px-4 py-2 text-gray-500 hover:text-gray-700"

        fullClass =
            if String.isEmpty extraClass then
                baseClass

            else
                baseClass ++ " " ++ extraClass
    in
    button
        [ type_ "button"
        , class fullClass
        , onClick (SwitchTab tab)
        ]
        [ text labelText ]
