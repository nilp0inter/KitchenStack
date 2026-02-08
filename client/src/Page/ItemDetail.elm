module Page.ItemDetail exposing
    ( Model
    , Msg
    , OutMsg(..)
    , init
    , update
    , view
    )

import Api
import Components
import Html exposing (..)
import Html.Attributes exposing (class, disabled, href)
import Html.Events exposing (onClick)
import Http
import Markdown.Parser
import Markdown.Renderer
import Types exposing (..)


type alias Model =
    { portionId : String
    , portionDetail : Maybe PortionDetail
    , loading : Bool
    , error : Maybe String
    }


type Msg
    = GotPortionDetail (Result Http.Error PortionDetail)
    | ConsumePortion String
    | PortionConsumed (Result Http.Error ())


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshBatches


init : String -> ( Model, Cmd Msg )
init portionId =
    ( { portionId = portionId
      , portionDetail = Nothing
      , loading = True
      , error = Nothing
      }
    , Api.fetchPortionDetail portionId GotPortionDetail
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotPortionDetail result ->
            case result of
                Ok detail ->
                    ( { model | portionDetail = Just detail, loading = False }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( { model | error = Just "Failed to load portion details", loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Failed to load portion details", notificationType = Error }
                    )

        ConsumePortion portionId ->
            ( { model | loading = True }
            , Api.consumePortion portionId PortionConsumed
            , NoOp
            )

        PortionConsumed result ->
            case result of
                Ok _ ->
                    ( { model | loading = False }
                    , Api.fetchPortionDetail model.portionId GotPortionDetail
                    , RefreshBatches
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Failed to consume portion", notificationType = Error }
                    )


view : Model -> Html Msg
view model =
    case model.portionDetail of
        Nothing ->
            if model.loading then
                Components.viewLoading

            else
                div [ class "text-center py-12" ]
                    [ span [ class "text-6xl" ] [ text "❓" ]
                    , h1 [ class "text-3xl font-bold text-gray-800 mt-4" ] [ text "Porción no encontrada" ]
                    , a [ href "/", class "btn-primary inline-block mt-4" ] [ text "Volver al inicio" ]
                    ]

        Just portion ->
            div [ class "max-w-lg mx-auto" ]
                [ div [ class "card text-center" ]
                    [ if portion.status == "CONSUMED" then
                        div []
                            [ span [ class "text-6xl" ] [ text "✅" ]
                            , h1 [ class "text-2xl font-bold text-gray-800 mt-4" ] [ text "Porción ya consumida" ]
                            , p [ class "text-gray-500 mt-2" ]
                                [ text ("Consumida el: " ++ Maybe.withDefault "?" portion.consumedAt) ]
                            ]

                      else
                        div []
                            [ span [ class "text-6xl" ] [ text "❄️" ]
                            , h1 [ class "text-2xl font-bold text-gray-800 mt-4" ] [ text portion.name ]
                            ]
                    , viewDetails portion
                    , if portion.status == "FROZEN" then
                        div [ class "mt-8" ]
                            [ button
                                [ onClick (ConsumePortion portion.portionId)
                                , class "w-full bg-green-500 hover:bg-green-600 text-white font-bold py-4 px-6 rounded-lg text-lg transition-colors"
                                , disabled model.loading
                                ]
                                [ if model.loading then
                                    text "Procesando..."

                                  else
                                    text "🍽️ Confirmar Consumo"
                                ]
                            ]

                      else
                        text ""
                    , div [ class "mt-4" ]
                        [ a [ href "/", class "text-frost-600 hover:text-frost-800" ] [ text "← Volver al inventario" ]
                        ]
                    ]
                ]


viewDetails : PortionDetail -> Html Msg
viewDetails portion =
    div [ class "mt-6 space-y-3 text-left" ]
        [ if portion.ingredients /= "" then
            detailRow "Ingredientes" portion.ingredients

          else
            text ""
        , detailRow "Envase" portion.containerId
        , detailRow "Congelado" portion.createdAt
        , detailRow "Caduca" portion.expiryDate
        , case portion.bestBeforeDate of
            Just bbDate ->
                detailRow "Consumo preferente" bbDate

            Nothing ->
                text ""
        , div [ class "flex justify-between py-2" ]
            [ span [ class "text-gray-500" ] [ text "Estado" ]
            , span
                [ class
                    (if portion.status == "FROZEN" then
                        "font-medium text-frost-600"

                     else
                        "font-medium text-green-600"
                    )
                ]
                [ text
                    (if portion.status == "FROZEN" then
                        "Congelada"

                     else
                        "Consumida"
                    )
                ]
            ]
        , viewMarkdownDetails portion.details
        ]


viewMarkdownDetails : Maybe String -> Html Msg
viewMarkdownDetails maybeDetails =
    case maybeDetails of
        Just details ->
            if String.trim details /= "" then
                div [ class "border-t pt-4 mt-4" ]
                    [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Detalles:" ]
                    , renderMarkdown details
                    ]

            else
                text ""

        Nothing ->
            text ""


renderMarkdown : String -> Html Msg
renderMarkdown markdown =
    case
        markdown
            |> Markdown.Parser.parse
            |> Result.mapError (\_ -> "Markdown parse error")
            |> Result.andThen (Markdown.Renderer.render Markdown.Renderer.defaultHtmlRenderer)
    of
        Ok rendered ->
            div [ class "prose prose-sm max-w-none text-gray-600" ] rendered

        Err _ ->
            div [ class "text-gray-600 whitespace-pre-wrap" ] [ text markdown ]


detailRow : String -> String -> Html Msg
detailRow label value =
    div [ class "flex justify-between py-2 border-b" ]
        [ span [ class "text-gray-500" ] [ text label ]
        , span [ class "font-medium" ] [ text value ]
        ]
