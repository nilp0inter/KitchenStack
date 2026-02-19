module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Components
import Html exposing (..)
import Html.Attributes exposing (class)
import Page.Home as Home
import Page.Home.Types as HomeTypes
import Page.Label as Label
import Page.Label.Types as LabelTypes
import Page.Labels as Labels
import Page.Labels.Types as LabelsTypes
import Page.NotFound as NotFound
import Page.Templates as Templates
import Page.Templates.Types as TemplatesTypes
import Ports
import Process
import Route exposing (Route(..))
import Task
import Types exposing (..)
import Url



-- MAIN


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , route : Route
    , currentDate : String
    , page : Page
    , notification : Maybe Notification
    , notificationIdCounter : Int
    }


type Page
    = TemplateListPage Templates.Model
    | TemplateEditorPage Home.Model
    | LabelListPage Labels.Model
    | LabelEditorPage Label.Model
    | NotFoundPage


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        route =
            Route.parseUrl url

        model =
            { key = key
            , url = url
            , route = route
            , currentDate = flags.currentDate
            , page = NotFoundPage
            , notification = Nothing
            , notificationIdCounter = 0
            }
    in
    initPage route model



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | HomeMsg Home.Msg
    | TemplatesMsg Templates.Msg
    | LabelsMsg Labels.Msg
    | LabelMsg Label.Msg
    | GotTextMeasureResult Ports.TextMeasureResult
    | GotPngResult Ports.PngResult
    | DismissNotification Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            let
                route =
                    Route.parseUrl url

                newModel =
                    { model | url = url, route = route }
            in
            initPage route newModel

        HomeMsg subMsg ->
            case model.page of
                TemplateEditorPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Home.update subMsg pageModel

                        newModel =
                            { model | page = TemplateEditorPage newPageModel }
                    in
                    handleHomeOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        TemplatesMsg subMsg ->
            case model.page of
                TemplateListPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Templates.update subMsg pageModel

                        newModel =
                            { model | page = TemplateListPage newPageModel }
                    in
                    handleTemplatesOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        LabelsMsg subMsg ->
            case model.page of
                LabelListPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Labels.update subMsg pageModel

                        newModel =
                            { model | page = LabelListPage newPageModel }
                    in
                    handleLabelsOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        LabelMsg subMsg ->
            case model.page of
                LabelEditorPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Label.update subMsg pageModel

                        newModel =
                            { model | page = LabelEditorPage newPageModel }
                    in
                    handleLabelOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        GotTextMeasureResult result ->
            case model.page of
                TemplateEditorPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Home.update (HomeTypes.GotTextMeasureResult result) pageModel

                        newModel =
                            { model | page = TemplateEditorPage newPageModel }
                    in
                    handleHomeOutMsg outMsg newModel pageCmd

                LabelEditorPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Label.update (LabelTypes.GotTextMeasureResult result) pageModel

                        newModel =
                            { model | page = LabelEditorPage newPageModel }
                    in
                    handleLabelOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        GotPngResult result ->
            case model.page of
                LabelEditorPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Label.update (LabelTypes.GotPngResult result) pageModel

                        newModel =
                            { model | page = LabelEditorPage newPageModel }
                    in
                    handleLabelOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        DismissNotification notificationId ->
            case model.notification of
                Just notification ->
                    if notification.id == notificationId then
                        ( { model | notification = Nothing }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )


initPage : Route -> Model -> ( Model, Cmd Msg )
initPage route model =
    case route of
        TemplateList ->
            let
                ( pageModel, pageCmd ) =
                    Templates.init

                newModel =
                    { model | page = TemplateListPage pageModel }
            in
            ( newModel, Cmd.map TemplatesMsg pageCmd )

        TemplateEditor uuid ->
            let
                ( pageModel, pageCmd, outMsg ) =
                    Home.init uuid

                newModel =
                    { model | page = TemplateEditorPage pageModel }
            in
            handleHomeOutMsg outMsg newModel pageCmd

        LabelList ->
            let
                ( pageModel, pageCmd ) =
                    Labels.init

                newModel =
                    { model | page = LabelListPage pageModel }
            in
            ( newModel, Cmd.map LabelsMsg pageCmd )

        LabelEditor uuid ->
            let
                ( pageModel, pageCmd, outMsg ) =
                    Label.init uuid

                newModel =
                    { model | page = LabelEditorPage pageModel }
            in
            handleLabelOutMsg outMsg newModel pageCmd

        NotFound ->
            ( { model | page = NotFoundPage }, Cmd.none )


setNotification : String -> NotificationType -> Model -> ( Model, Cmd Msg )
setNotification message notificationType model =
    let
        newId =
            model.notificationIdCounter + 1

        notification =
            { id = newId
            , message = message
            , notificationType = notificationType
            }

        dismissCmd =
            case notificationType of
                Error ->
                    Cmd.none

                _ ->
                    Process.sleep 5000
                        |> Task.perform (\_ -> DismissNotification newId)
    in
    ( { model
        | notification = Just notification
        , notificationIdCounter = newId
      }
    , dismissCmd
    )


handleHomeOutMsg : Home.OutMsg -> Model -> Cmd Home.Msg -> ( Model, Cmd Msg )
handleHomeOutMsg outMsg model pageCmd =
    case outMsg of
        HomeTypes.NoOutMsg ->
            ( model, Cmd.map HomeMsg pageCmd )

        HomeTypes.RequestTextMeasures requests ->
            ( model
            , Cmd.batch
                (Cmd.map HomeMsg pageCmd
                    :: List.map Ports.requestTextMeasure requests
                )
            )


handleTemplatesOutMsg : Templates.OutMsg -> Model -> Cmd Templates.Msg -> ( Model, Cmd Msg )
handleTemplatesOutMsg outMsg model pageCmd =
    case outMsg of
        TemplatesTypes.NoOutMsg ->
            ( model, Cmd.map TemplatesMsg pageCmd )

        TemplatesTypes.NavigateTo url ->
            ( model
            , Cmd.batch
                [ Cmd.map TemplatesMsg pageCmd
                , Nav.pushUrl model.key url
                ]
            )


handleLabelsOutMsg : Labels.OutMsg -> Model -> Cmd Labels.Msg -> ( Model, Cmd Msg )
handleLabelsOutMsg outMsg model pageCmd =
    case outMsg of
        LabelsTypes.NoOutMsg ->
            ( model, Cmd.map LabelsMsg pageCmd )

        LabelsTypes.NavigateTo url ->
            ( model
            , Cmd.batch
                [ Cmd.map LabelsMsg pageCmd
                , Nav.pushUrl model.key url
                ]
            )


handleLabelOutMsg : Label.OutMsg -> Model -> Cmd Label.Msg -> ( Model, Cmd Msg )
handleLabelOutMsg outMsg model pageCmd =
    case outMsg of
        LabelTypes.NoOutMsg ->
            ( model, Cmd.map LabelMsg pageCmd )

        LabelTypes.RequestTextMeasures requests ->
            ( model
            , Cmd.batch
                (Cmd.map LabelMsg pageCmd
                    :: List.map Ports.requestTextMeasure requests
                )
            )

        LabelTypes.RequestSvgToPng request ->
            ( model
            , Cmd.batch
                [ Cmd.map LabelMsg pageCmd
                , Ports.requestSvgToPng request
                ]
            )

        LabelTypes.ShowNotification message notificationType ->
            let
                ( notifiedModel, notifyCmd ) =
                    setNotification message notificationType model
            in
            ( notifiedModel
            , Cmd.batch
                [ Cmd.map LabelMsg pageCmd
                , notifyCmd
                ]
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.receiveTextMeasureResult GotTextMeasureResult
        , Ports.receivePngResult GotPngResult
        ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "LabelMaker"
    , body =
        [ div [ class "min-h-screen bg-gray-100" ]
            [ Components.viewHeader model.route
            , Components.viewNotification model.notification DismissNotification
            , main_ [ class "container mx-auto px-4 py-8" ]
                [ viewPage model
                ]
            ]
        ]
    }


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        TemplateListPage pageModel ->
            Html.map TemplatesMsg (Templates.view pageModel)

        TemplateEditorPage pageModel ->
            Html.map HomeMsg (Home.view pageModel)

        LabelListPage pageModel ->
            Html.map LabelsMsg (Labels.view pageModel)

        LabelEditorPage pageModel ->
            Html.map LabelMsg (Label.view pageModel)

        NotFoundPage ->
            NotFound.view
