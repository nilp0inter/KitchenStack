module Main exposing (main)

import Api
import Browser
import Browser.Navigation as Nav
import Components
import Html exposing (..)
import Html.Attributes exposing (class)
import Http
import Page.BatchDetail as BatchDetail
import Page.ContainerTypes as ContainerTypes
import Page.Dashboard as Dashboard
import Page.History as History
import Page.Ingredients as Ingredients
import Page.ItemDetail as ItemDetail
import Page.NewBatch as NewBatch
import Page.NotFound as NotFound
import Page.Recipes as Recipes
import Route exposing (Route(..))
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
    , ingredients : List Ingredient
    , containerTypes : List ContainerType
    , batches : List BatchSummary
    , recipes : List Recipe
    , page : Page
    , notification : Maybe Notification
    , printingProgress : Maybe PrintingProgress
    , loading : Bool
    }


type Page
    = DashboardPage Dashboard.Model
    | NewBatchPage NewBatch.Model
    | ItemDetailPage ItemDetail.Model
    | BatchDetailPage BatchDetail.Model
    | HistoryPage History.Model
    | ContainerTypesPage ContainerTypes.Model
    | IngredientsPage Ingredients.Model
    | RecipesPage Recipes.Model
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
            , ingredients = []
            , containerTypes = []
            , batches = []
            , recipes = []
            , page = NotFoundPage
            , notification = Nothing
            , printingProgress = Nothing
            , loading = True
            }
    in
    ( model
    , Cmd.batch
        [ Api.fetchIngredients GotIngredients
        , Api.fetchContainerTypes GotContainerTypes
        , Api.fetchBatches GotBatches
        , Api.fetchRecipes GotRecipes
        ]
    )


initPage : Route -> Model -> ( Model, Cmd Msg )
initPage route model =
    case route of
        Dashboard ->
            let
                ( pageModel, pageCmd ) =
                    Dashboard.init model.batches model.containerTypes
            in
            ( { model | page = DashboardPage pageModel }
            , Cmd.map DashboardMsg pageCmd
            )

        NewBatch ->
            let
                ( pageModel, pageCmd ) =
                    NewBatch.init model.currentDate model.ingredients model.containerTypes model.recipes
            in
            ( { model | page = NewBatchPage pageModel }
            , Cmd.map NewBatchMsg pageCmd
            )

        ItemDetail portionId ->
            let
                ( pageModel, pageCmd ) =
                    ItemDetail.init portionId
            in
            ( { model | page = ItemDetailPage pageModel }
            , Cmd.map ItemDetailMsg pageCmd
            )

        BatchDetail batchId ->
            let
                ( pageModel, pageCmd ) =
                    BatchDetail.init batchId model.batches
            in
            ( { model | page = BatchDetailPage pageModel }
            , Cmd.map BatchDetailMsg pageCmd
            )

        History ->
            let
                ( pageModel, pageCmd ) =
                    History.init
            in
            ( { model | page = HistoryPage pageModel }
            , Cmd.map HistoryMsg pageCmd
            )

        ContainerTypes ->
            let
                ( pageModel, pageCmd ) =
                    ContainerTypes.init model.containerTypes
            in
            ( { model | page = ContainerTypesPage pageModel }
            , Cmd.map ContainerTypesMsg pageCmd
            )

        Route.Ingredients ->
            let
                ( pageModel, pageCmd ) =
                    Ingredients.init model.ingredients
            in
            ( { model | page = IngredientsPage pageModel }
            , Cmd.map IngredientsMsg pageCmd
            )

        Route.Recipes ->
            let
                ( pageModel, pageCmd ) =
                    Recipes.init model.recipes model.ingredients model.containerTypes
            in
            ( { model | page = RecipesPage pageModel }
            , Cmd.map RecipesMsg pageCmd
            )

        NotFound ->
            ( { model | page = NotFoundPage }, Cmd.none )



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotIngredients (Result Http.Error (List Ingredient))
    | GotContainerTypes (Result Http.Error (List ContainerType))
    | GotBatches (Result Http.Error (List BatchSummary))
    | GotRecipes (Result Http.Error (List Recipe))
    | DashboardMsg Dashboard.Msg
    | NewBatchMsg NewBatch.Msg
    | ItemDetailMsg ItemDetail.Msg
    | BatchDetailMsg BatchDetail.Msg
    | HistoryMsg History.Msg
    | ContainerTypesMsg ContainerTypes.Msg
    | IngredientsMsg Ingredients.Msg
    | RecipesMsg Recipes.Msg
    | DismissNotification
    | NavigateToBatch String


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

        GotIngredients result ->
            case result of
                Ok ingredients ->
                    let
                        newModel =
                            { model | ingredients = ingredients }
                    in
                    maybeInitPage newModel

                Err _ ->
                    ( { model | notification = Just { message = "Failed to load ingredients", notificationType = Error } }
                    , Cmd.none
                    )

        GotContainerTypes result ->
            case result of
                Ok containerTypes ->
                    let
                        newModel =
                            { model | containerTypes = containerTypes, loading = False }
                    in
                    maybeInitPage newModel

                Err _ ->
                    ( { model
                        | notification = Just { message = "Failed to load container types", notificationType = Error }
                        , loading = False
                      }
                    , Cmd.none
                    )

        GotBatches result ->
            case result of
                Ok batches ->
                    let
                        newModel =
                            { model | batches = batches, loading = False }
                    in
                    maybeInitPage newModel

                Err _ ->
                    ( { model
                        | notification = Just { message = "Failed to load batches", notificationType = Error }
                        , loading = False
                      }
                    , Cmd.none
                    )

        GotRecipes result ->
            case result of
                Ok recipes ->
                    let
                        newModel =
                            { model | recipes = recipes }
                    in
                    maybeInitPage newModel

                Err _ ->
                    ( { model | notification = Just { message = "Failed to load recipes", notificationType = Error } }
                    , Cmd.none
                    )

        DashboardMsg subMsg ->
            case model.page of
                DashboardPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Dashboard.update subMsg pageModel

                        newModel =
                            { model | page = DashboardPage newPageModel }
                    in
                    handleDashboardOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        NewBatchMsg subMsg ->
            case model.page of
                NewBatchPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            NewBatch.update subMsg pageModel

                        newModel =
                            { model
                                | page = NewBatchPage newPageModel
                                , printingProgress = newPageModel.printingProgress
                            }
                    in
                    handleNewBatchOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        ItemDetailMsg subMsg ->
            case model.page of
                ItemDetailPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            ItemDetail.update subMsg pageModel

                        newModel =
                            { model | page = ItemDetailPage newPageModel }
                    in
                    handleItemDetailOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        BatchDetailMsg subMsg ->
            case model.page of
                BatchDetailPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            BatchDetail.update subMsg pageModel

                        newModel =
                            { model
                                | page = BatchDetailPage newPageModel
                                , printingProgress = newPageModel.printingProgress
                            }
                    in
                    handleBatchDetailOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        HistoryMsg subMsg ->
            case model.page of
                HistoryPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            History.update subMsg pageModel

                        newModel =
                            { model | page = HistoryPage newPageModel }
                    in
                    handleHistoryOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        ContainerTypesMsg subMsg ->
            case model.page of
                ContainerTypesPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            ContainerTypes.update subMsg pageModel

                        newModel =
                            { model | page = ContainerTypesPage newPageModel }
                    in
                    handleContainerTypesOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        IngredientsMsg subMsg ->
            case model.page of
                IngredientsPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Ingredients.update subMsg pageModel

                        newModel =
                            { model | page = IngredientsPage newPageModel }
                    in
                    handleIngredientsOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        RecipesMsg subMsg ->
            case model.page of
                RecipesPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Recipes.update subMsg pageModel

                        newModel =
                            { model | page = RecipesPage newPageModel }
                    in
                    handleRecipesOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        DismissNotification ->
            ( { model | notification = Nothing }, Cmd.none )

        NavigateToBatch batchId ->
            ( model, Nav.pushUrl model.key ("/batch/" ++ batchId) )


maybeInitPage : Model -> ( Model, Cmd Msg )
maybeInitPage model =
    if not (List.isEmpty model.ingredients) && not (List.isEmpty model.containerTypes) then
        case model.page of
            NotFoundPage ->
                initPage model.route model

            _ ->
                ( model, Cmd.none )

    else
        ( model, Cmd.none )


handleDashboardOutMsg : Dashboard.OutMsg -> Model -> Cmd Dashboard.Msg -> ( Model, Cmd Msg )
handleDashboardOutMsg outMsg model pageCmd =
    case outMsg of
        Dashboard.NoOp ->
            ( model, Cmd.map DashboardMsg pageCmd )

        Dashboard.NavigateToBatch batchId ->
            ( model
            , Cmd.batch
                [ Cmd.map DashboardMsg pageCmd
                , Nav.pushUrl model.key ("/batch/" ++ batchId)
                ]
            )

        Dashboard.ShowError message ->
            ( { model | notification = Just { message = message, notificationType = Error } }
            , Cmd.map DashboardMsg pageCmd
            )


handleNewBatchOutMsg : NewBatch.OutMsg -> Model -> Cmd NewBatch.Msg -> ( Model, Cmd Msg )
handleNewBatchOutMsg outMsg model pageCmd =
    case outMsg of
        NewBatch.NoOp ->
            ( model, Cmd.map NewBatchMsg pageCmd )

        NewBatch.ShowNotification notification ->
            ( { model | notification = Just notification }
            , Cmd.map NewBatchMsg pageCmd
            )

        NewBatch.NavigateToHome ->
            ( model
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , Nav.pushUrl model.key "/"
                ]
            )

        NewBatch.NavigateToBatch batchId ->
            ( model
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , Nav.pushUrl model.key ("/batch/" ++ batchId)
                ]
            )

        NewBatch.RefreshBatches ->
            ( model
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , Api.fetchBatches GotBatches
                , Api.fetchIngredients GotIngredients
                ]
            )


handleItemDetailOutMsg : ItemDetail.OutMsg -> Model -> Cmd ItemDetail.Msg -> ( Model, Cmd Msg )
handleItemDetailOutMsg outMsg model pageCmd =
    case outMsg of
        ItemDetail.NoOp ->
            ( model, Cmd.map ItemDetailMsg pageCmd )

        ItemDetail.ShowNotification notification ->
            ( { model | notification = Just notification }
            , Cmd.map ItemDetailMsg pageCmd
            )

        ItemDetail.RefreshBatches ->
            ( { model | notification = Just { message = "Porción marcada como consumida", notificationType = Success } }
            , Cmd.batch
                [ Cmd.map ItemDetailMsg pageCmd
                , Api.fetchBatches GotBatches
                ]
            )


handleBatchDetailOutMsg : BatchDetail.OutMsg -> Model -> Cmd BatchDetail.Msg -> ( Model, Cmd Msg )
handleBatchDetailOutMsg outMsg model pageCmd =
    case outMsg of
        BatchDetail.NoOp ->
            ( model, Cmd.map BatchDetailMsg pageCmd )

        BatchDetail.ShowNotification notification ->
            ( { model | notification = Just notification }
            , Cmd.map BatchDetailMsg pageCmd
            )


handleHistoryOutMsg : History.OutMsg -> Model -> Cmd History.Msg -> ( Model, Cmd Msg )
handleHistoryOutMsg outMsg model pageCmd =
    case outMsg of
        History.NoOp ->
            ( model, Cmd.map HistoryMsg pageCmd )

        History.ShowError message ->
            ( { model | notification = Just { message = message, notificationType = Error } }
            , Cmd.map HistoryMsg pageCmd
            )


handleContainerTypesOutMsg : ContainerTypes.OutMsg -> Model -> Cmd ContainerTypes.Msg -> ( Model, Cmd Msg )
handleContainerTypesOutMsg outMsg model pageCmd =
    case outMsg of
        ContainerTypes.NoOp ->
            ( model, Cmd.map ContainerTypesMsg pageCmd )

        ContainerTypes.ShowNotification notification ->
            ( { model | notification = Just notification }
            , Cmd.map ContainerTypesMsg pageCmd
            )


handleIngredientsOutMsg : Ingredients.OutMsg -> Model -> Cmd Ingredients.Msg -> ( Model, Cmd Msg )
handleIngredientsOutMsg outMsg model pageCmd =
    case outMsg of
        Ingredients.NoOp ->
            ( model, Cmd.map IngredientsMsg pageCmd )

        Ingredients.ShowNotification notification ->
            ( { model | notification = Just notification }
            , Cmd.map IngredientsMsg pageCmd
            )

        Ingredients.RefreshIngredients ->
            ( model
            , Cmd.batch
                [ Cmd.map IngredientsMsg pageCmd
                , Api.fetchIngredients GotIngredients
                ]
            )


handleRecipesOutMsg : Recipes.OutMsg -> Model -> Cmd Recipes.Msg -> ( Model, Cmd Msg )
handleRecipesOutMsg outMsg model pageCmd =
    case outMsg of
        Recipes.NoOp ->
            ( model, Cmd.map RecipesMsg pageCmd )

        Recipes.ShowNotification notification ->
            ( { model | notification = Just notification }
            , Cmd.map RecipesMsg pageCmd
            )

        Recipes.RefreshRecipes ->
            ( model
            , Cmd.batch
                [ Cmd.map RecipesMsg pageCmd
                , Api.fetchRecipes GotRecipes
                , Api.fetchIngredients GotIngredients
                ]
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "FrostByte"
    , body =
        [ div [ class "min-h-screen bg-gray-100" ]
            [ Components.viewHeader model.route
            , Components.viewNotification model.notification DismissNotification
            , Components.viewPrintingProgress model.printingProgress
            , main_ [ class "container mx-auto px-4 py-8" ]
                [ if model.loading then
                    Components.viewLoading

                  else
                    viewPage model
                ]
            ]
        ]
    }


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        DashboardPage pageModel ->
            Dashboard.view pageModel NavigateToBatch

        NewBatchPage pageModel ->
            Html.map NewBatchMsg (NewBatch.view pageModel)

        ItemDetailPage pageModel ->
            Html.map ItemDetailMsg (ItemDetail.view pageModel)

        BatchDetailPage pageModel ->
            Html.map BatchDetailMsg (BatchDetail.view pageModel)

        HistoryPage pageModel ->
            Html.map HistoryMsg (History.view pageModel)

        ContainerTypesPage pageModel ->
            Html.map ContainerTypesMsg (ContainerTypes.view pageModel)

        IngredientsPage pageModel ->
            Html.map IngredientsMsg (Ingredients.view pageModel)

        RecipesPage pageModel ->
            Html.map RecipesMsg (Recipes.view pageModel)

        NotFoundPage ->
            NotFound.view
