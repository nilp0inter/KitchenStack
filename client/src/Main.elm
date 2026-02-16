module Main exposing (main)

import Api
import Browser
import Browser.Navigation as Nav
import Components
import Html exposing (..)
import Html.Attributes exposing (class)
import Http
import Process
import Task
import Page.BatchDetail as BatchDetail
import Page.BatchDetail.Types as BatchDetailTypes
import Page.ContainerTypes as ContainerTypes
import Page.ContainerTypes.Types as ContainerTypesTypes
import Page.Inventory as Inventory
import Page.Inventory.Types as InventoryTypes
import Page.Menu as Menu
import Page.Menu.Types as MenuTypes
import Page.History as History
import Page.History.Types as HistoryTypes
import Page.Ingredients as Ingredients
import Page.Ingredients.Types as IngredientsTypes
import Page.ItemDetail as ItemDetail
import Page.ItemDetail.Types as ItemDetailTypes
import Page.LabelDesigner as LabelDesigner
import Page.LabelDesigner.Types as LabelDesignerTypes
import Page.NewBatch as NewBatch
import Page.NewBatch.Types as NewBatchTypes
import Page.NotFound as NotFound
import Page.Recipes as Recipes
import Page.Recipes.Types as RecipesTypes
import Ports
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
    , appHost : String
    , ingredients : RemoteData (List Ingredient)
    , containerTypes : RemoteData (List ContainerType)
    , batches : RemoteData (List BatchSummary)
    , recipes : RemoteData (List Recipe)
    , labelPresets : RemoteData (List LabelPreset)
    , page : Page
    , notification : Maybe Notification
    , notificationIdCounter : Int
    , printingProgress : Maybe PrintingProgress
    , mobileMenuOpen : Bool
    , configDropdownOpen : Bool
    }


type Page
    = MenuPage Menu.Model
    | InventoryPage Inventory.Model
    | NewBatchPage NewBatch.Model
    | ItemDetailPage ItemDetail.Model
    | BatchDetailPage BatchDetail.Model
    | HistoryPage History.Model
    | ContainerTypesPage ContainerTypes.Model
    | IngredientsPage Ingredients.Model
    | RecipesPage Recipes.Model
    | LabelDesignerPage LabelDesigner.Model
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
            , appHost = flags.appHost
            , ingredients = Loading
            , containerTypes = Loading
            , batches = Loading
            , recipes = Loading
            , labelPresets = Loading
            , page = NotFoundPage
            , notification = Nothing
            , notificationIdCounter = 0
            , printingProgress = Nothing
            , mobileMenuOpen = False
            , configDropdownOpen = False
            }
    in
    ( model
    , Cmd.batch
        [ Api.fetchIngredients GotIngredients
        , Api.fetchContainerTypes GotContainerTypes
        , Api.fetchBatches GotBatches
        , Api.fetchRecipes GotRecipes
        , Api.fetchLabelPresets GotLabelPresets
        ]
    )


{-| Extract data from RemoteData, providing an empty list as default.
-}
remoteDataToList : RemoteData (List a) -> List a
remoteDataToList rd =
    case rd of
        Loaded data ->
            data

        _ ->
            []


initPage : Route -> Model -> ( Model, Cmd Msg )
initPage route model =
    let
        ingredients =
            remoteDataToList model.ingredients

        containerTypes =
            remoteDataToList model.containerTypes

        batches =
            remoteDataToList model.batches

        recipes =
            remoteDataToList model.recipes

        labelPresets =
            remoteDataToList model.labelPresets
    in
    case route of
        Menu ->
            let
                ( pageModel, pageCmd ) =
                    Menu.init batches
            in
            ( { model | page = MenuPage pageModel }
            , Cmd.map MenuMsg pageCmd
            )

        Inventory ->
            let
                ( pageModel, pageCmd ) =
                    Inventory.init batches containerTypes
            in
            ( { model | page = InventoryPage pageModel }
            , Cmd.map InventoryMsg pageCmd
            )

        NewBatch ->
            let
                ( pageModel, pageCmd ) =
                    NewBatch.init model.currentDate model.appHost ingredients containerTypes recipes labelPresets
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
                    BatchDetail.init batchId model.appHost batches labelPresets
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
                    ContainerTypes.init containerTypes
            in
            ( { model | page = ContainerTypesPage pageModel }
            , Cmd.map ContainerTypesMsg pageCmd
            )

        Route.Ingredients ->
            let
                ( pageModel, pageCmd ) =
                    Ingredients.init ingredients
            in
            ( { model | page = IngredientsPage pageModel }
            , Cmd.map IngredientsMsg pageCmd
            )

        Route.Recipes ->
            let
                ( pageModel, pageCmd ) =
                    Recipes.init recipes ingredients containerTypes labelPresets
            in
            ( { model | page = RecipesPage pageModel }
            , Cmd.map RecipesMsg pageCmd
            )

        Route.LabelDesigner ->
            let
                ( pageModel, pageCmd, outMsg ) =
                    LabelDesigner.init model.appHost labelPresets

                newModel =
                    { model | page = LabelDesignerPage pageModel }

                ( finalModel, cmd ) =
                    handleLabelDesignerOutMsg outMsg newModel pageCmd
            in
            ( finalModel
            , Cmd.batch
                [ cmd
                , Ports.initPinchZoom { elementId = "label-preview-container", initialZoom = 1.0 }
                ]
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
    | GotLabelPresets (Result Http.Error (List LabelPreset))
    | MenuMsg Menu.Msg
    | InventoryMsg Inventory.Msg
    | NewBatchMsg NewBatch.Msg
    | ItemDetailMsg ItemDetail.Msg
    | BatchDetailMsg BatchDetail.Msg
    | HistoryMsg History.Msg
    | ContainerTypesMsg ContainerTypes.Msg
    | IngredientsMsg Ingredients.Msg
    | RecipesMsg Recipes.Msg
    | LabelDesignerMsg LabelDesigner.Msg
    | DismissNotification Int
    | NavigateToBatch String
    | GotPngResult Ports.PngResult
    | GotTextMeasureResult Ports.TextMeasureResult
    | GotPinchZoomUpdate Ports.PinchZoomUpdate
    | GotFileSelectResult Ports.FileSelectResult
    | ToggleMobileMenu
    | ToggleConfigDropdown


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
                    { model | url = url, route = route, mobileMenuOpen = False, configDropdownOpen = False }
            in
            initPage route newModel

        GotIngredients result ->
            case result of
                Ok ingredients ->
                    let
                        updatedModel =
                            { model | ingredients = Loaded ingredients }

                        ( initedModel, initCmd ) =
                            maybeInitPage updatedModel

                        ( dispatchedModel, dispatchCmd ) =
                            dispatchIngredientsToPage ingredients initedModel
                    in
                    ( dispatchedModel, Cmd.batch [ initCmd, dispatchCmd ] )

                Err _ ->
                    let
                        ( newModel, cmd ) =
                            setNotification "Failed to load ingredients" Error model
                    in
                    maybeInitPage { newModel | ingredients = Failed "Failed to load ingredients" }
                        |> Tuple.mapSecond (\c -> Cmd.batch [ cmd, c ])

        GotContainerTypes result ->
            case result of
                Ok containerTypes ->
                    let
                        updatedModel =
                            { model | containerTypes = Loaded containerTypes }

                        ( initedModel, initCmd ) =
                            maybeInitPage updatedModel

                        ( dispatchedModel, dispatchCmd ) =
                            dispatchContainerTypesToPage containerTypes initedModel
                    in
                    ( dispatchedModel, Cmd.batch [ initCmd, dispatchCmd ] )

                Err _ ->
                    let
                        ( newModel, cmd ) =
                            setNotification "Failed to load container types" Error model
                    in
                    maybeInitPage { newModel | containerTypes = Failed "Failed to load container types" }
                        |> Tuple.mapSecond (\c -> Cmd.batch [ cmd, c ])

        GotBatches result ->
            case result of
                Ok batches ->
                    let
                        updatedModel =
                            { model | batches = Loaded batches }

                        ( initedModel, initCmd ) =
                            maybeInitPage updatedModel

                        ( dispatchedModel, dispatchCmd ) =
                            dispatchBatchesToPage batches initedModel
                    in
                    ( dispatchedModel, Cmd.batch [ initCmd, dispatchCmd ] )

                Err _ ->
                    let
                        ( newModel, cmd ) =
                            setNotification "Failed to load batches" Error model
                    in
                    maybeInitPage { newModel | batches = Failed "Failed to load batches" }
                        |> Tuple.mapSecond (\c -> Cmd.batch [ cmd, c ])

        GotRecipes result ->
            case result of
                Ok recipes ->
                    let
                        updatedModel =
                            { model | recipes = Loaded recipes }

                        ( initedModel, initCmd ) =
                            maybeInitPage updatedModel

                        ( dispatchedModel, dispatchCmd ) =
                            dispatchRecipesToPage recipes initedModel
                    in
                    ( dispatchedModel, Cmd.batch [ initCmd, dispatchCmd ] )

                Err _ ->
                    let
                        ( newModel, cmd ) =
                            setNotification "Failed to load recipes" Error model
                    in
                    maybeInitPage { newModel | recipes = Failed "Failed to load recipes" }
                        |> Tuple.mapSecond (\c -> Cmd.batch [ cmd, c ])

        GotLabelPresets result ->
            case result of
                Ok labelPresets ->
                    let
                        updatedModel =
                            { model | labelPresets = Loaded labelPresets }

                        ( initedModel, initCmd ) =
                            maybeInitPage updatedModel

                        ( dispatchedModel, dispatchCmd ) =
                            dispatchPresetsToPage labelPresets initedModel
                    in
                    ( dispatchedModel, Cmd.batch [ initCmd, dispatchCmd ] )

                Err _ ->
                    let
                        ( newModel, cmd ) =
                            setNotification "Failed to load label presets" Error model
                    in
                    maybeInitPage { newModel | labelPresets = Failed "Failed to load label presets" }
                        |> Tuple.mapSecond (\c -> Cmd.batch [ cmd, c ])

        MenuMsg subMsg ->
            case model.page of
                MenuPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Menu.update subMsg pageModel

                        newModel =
                            { model | page = MenuPage newPageModel }
                    in
                    handleMenuOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        InventoryMsg subMsg ->
            case model.page of
                InventoryPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            Inventory.update subMsg pageModel

                        newModel =
                            { model | page = InventoryPage newPageModel }
                    in
                    handleInventoryOutMsg outMsg newModel pageCmd

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

        LabelDesignerMsg subMsg ->
            case model.page of
                LabelDesignerPage pageModel ->
                    let
                        ( newPageModel, pageCmd, outMsg ) =
                            LabelDesigner.update subMsg pageModel

                        newModel =
                            { model | page = LabelDesignerPage newPageModel }
                    in
                    handleLabelDesignerOutMsg outMsg newModel pageCmd

                _ ->
                    ( model, Cmd.none )

        GotPngResult pngResult ->
            -- Forward PNG results to the active page that handles printing
            case model.page of
                NewBatchPage _ ->
                    update (NewBatchMsg (NewBatchTypes.GotPngResult pngResult)) model

                BatchDetailPage _ ->
                    update (BatchDetailMsg (BatchDetailTypes.GotPngResult pngResult)) model

                LabelDesignerPage _ ->
                    update (LabelDesignerMsg (LabelDesignerTypes.GotPngResult pngResult)) model

                _ ->
                    ( model, Cmd.none )

        GotTextMeasureResult measureResult ->
            -- Forward text measurement results to the active page that handles it
            case model.page of
                NewBatchPage _ ->
                    update (NewBatchMsg (NewBatchTypes.GotTextMeasureResult measureResult)) model

                BatchDetailPage _ ->
                    update (BatchDetailMsg (BatchDetailTypes.GotTextMeasureResult measureResult)) model

                LabelDesignerPage _ ->
                    update (LabelDesignerMsg (LabelDesignerTypes.GotTextMeasureResult measureResult)) model

                _ ->
                    ( model, Cmd.none )

        GotPinchZoomUpdate zoomUpdate ->
            -- Forward pinch zoom updates to LabelDesigner page
            case model.page of
                LabelDesignerPage _ ->
                    update (LabelDesignerMsg (LabelDesignerTypes.PinchZoomUpdated zoomUpdate)) model

                _ ->
                    ( model, Cmd.none )

        GotFileSelectResult fileResult ->
            -- Forward file selection results to the active page that handles it
            case model.page of
                RecipesPage _ ->
                    update (RecipesMsg (RecipesTypes.GotImageResult fileResult)) model

                NewBatchPage _ ->
                    update (NewBatchMsg (NewBatchTypes.GotImageResult fileResult)) model

                _ ->
                    ( model, Cmd.none )

        DismissNotification notificationId ->
            case model.notification of
                Just notification ->
                    if notification.id == notificationId then
                        ( { model | notification = Nothing }, Cmd.none )

                    else
                        -- Ignore: timer was for an old notification
                        ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        NavigateToBatch batchId ->
            ( model, Nav.pushUrl model.key ("/batch/" ++ batchId) )

        ToggleMobileMenu ->
            ( { model | mobileMenuOpen = not model.mobileMenuOpen }, Cmd.none )

        ToggleConfigDropdown ->
            ( { model | configDropdownOpen = not model.configDropdownOpen }, Cmd.none )


{-| Check if RemoteData is in a terminal state (Loaded or Failed).
-}
isSettled : RemoteData a -> Bool
isSettled rd =
    case rd of
        Loaded _ ->
            True

        Failed _ ->
            True

        _ ->
            False


{-| Check if RemoteData is successfully loaded.
-}
isLoaded : RemoteData a -> Bool
isLoaded rd =
    case rd of
        Loaded _ ->
            True

        _ ->
            False


{-| Check if all RemoteData values are loaded (not failed).
-}
allLoaded : Model -> Bool
allLoaded model =
    isLoaded model.ingredients
        && isLoaded model.containerTypes
        && isLoaded model.batches
        && isLoaded model.recipes
        && isLoaded model.labelPresets


{-| Check if all RemoteData values have settled (loaded or failed).
-}
allSettled : Model -> Bool
allSettled model =
    isSettled model.ingredients
        && isSettled model.containerTypes
        && isSettled model.batches
        && isSettled model.recipes
        && isSettled model.labelPresets


maybeInitPage : Model -> ( Model, Cmd Msg )
maybeInitPage model =
    if allSettled model then
        case model.page of
            NotFoundPage ->
                initPage model.route model

            _ ->
                ( model, Cmd.none )

    else
        ( model, Cmd.none )


{-| Dispatch updated batches to the active page.
-}
dispatchBatchesToPage : List BatchSummary -> Model -> ( Model, Cmd Msg )
dispatchBatchesToPage batches model =
    case model.page of
        MenuPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    Menu.update (MenuTypes.ReceivedBatches batches) pageModel
            in
            ( { model | page = MenuPage newPageModel }, Cmd.map MenuMsg pageCmd )

        InventoryPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    Inventory.update (InventoryTypes.ReceivedBatches batches) pageModel
            in
            ( { model | page = InventoryPage newPageModel }, Cmd.map InventoryMsg pageCmd )

        BatchDetailPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    BatchDetail.update (BatchDetailTypes.ReceivedBatches batches) pageModel
            in
            ( { model | page = BatchDetailPage newPageModel }, Cmd.map BatchDetailMsg pageCmd )

        _ ->
            ( model, Cmd.none )


{-| Dispatch updated ingredients to the active page.
-}
dispatchIngredientsToPage : List Ingredient -> Model -> ( Model, Cmd Msg )
dispatchIngredientsToPage ingredients model =
    case model.page of
        NewBatchPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    NewBatch.update (NewBatchTypes.ReceivedIngredients ingredients) pageModel
            in
            ( { model | page = NewBatchPage newPageModel }, Cmd.map NewBatchMsg pageCmd )

        IngredientsPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    Ingredients.update (IngredientsTypes.ReceivedIngredients ingredients) pageModel
            in
            ( { model | page = IngredientsPage newPageModel }, Cmd.map IngredientsMsg pageCmd )

        RecipesPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    Recipes.update (RecipesTypes.ReceivedIngredients ingredients) pageModel
            in
            ( { model | page = RecipesPage newPageModel }, Cmd.map RecipesMsg pageCmd )

        _ ->
            ( model, Cmd.none )


{-| Dispatch updated container types to the active page.
-}
dispatchContainerTypesToPage : List ContainerType -> Model -> ( Model, Cmd Msg )
dispatchContainerTypesToPage containerTypes model =
    case model.page of
        InventoryPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    Inventory.update (InventoryTypes.ReceivedContainerTypes containerTypes) pageModel
            in
            ( { model | page = InventoryPage newPageModel }, Cmd.map InventoryMsg pageCmd )

        NewBatchPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    NewBatch.update (NewBatchTypes.ReceivedContainerTypes containerTypes) pageModel
            in
            ( { model | page = NewBatchPage newPageModel }, Cmd.map NewBatchMsg pageCmd )

        ContainerTypesPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    ContainerTypes.update (ContainerTypesTypes.ReceivedContainerTypes containerTypes) pageModel
            in
            ( { model | page = ContainerTypesPage newPageModel }, Cmd.map ContainerTypesMsg pageCmd )

        RecipesPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    Recipes.update (RecipesTypes.ReceivedContainerTypes containerTypes) pageModel
            in
            ( { model | page = RecipesPage newPageModel }, Cmd.map RecipesMsg pageCmd )

        _ ->
            ( model, Cmd.none )


{-| Dispatch updated recipes to the active page.
-}
dispatchRecipesToPage : List Recipe -> Model -> ( Model, Cmd Msg )
dispatchRecipesToPage recipes model =
    case model.page of
        NewBatchPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    NewBatch.update (NewBatchTypes.ReceivedRecipes recipes) pageModel
            in
            ( { model | page = NewBatchPage newPageModel }, Cmd.map NewBatchMsg pageCmd )

        RecipesPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    Recipes.update (RecipesTypes.ReceivedRecipes recipes) pageModel
            in
            ( { model | page = RecipesPage newPageModel }, Cmd.map RecipesMsg pageCmd )

        _ ->
            ( model, Cmd.none )


{-| Dispatch updated label presets to the active page.
-}
dispatchPresetsToPage : List LabelPreset -> Model -> ( Model, Cmd Msg )
dispatchPresetsToPage labelPresets model =
    case model.page of
        NewBatchPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    NewBatch.update (NewBatchTypes.ReceivedLabelPresets labelPresets) pageModel
            in
            ( { model | page = NewBatchPage newPageModel }, Cmd.map NewBatchMsg pageCmd )

        BatchDetailPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    BatchDetail.update (BatchDetailTypes.ReceivedLabelPresets labelPresets) pageModel
            in
            ( { model | page = BatchDetailPage newPageModel }, Cmd.map BatchDetailMsg pageCmd )

        RecipesPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    Recipes.update (RecipesTypes.ReceivedLabelPresets labelPresets) pageModel
            in
            ( { model | page = RecipesPage newPageModel }, Cmd.map RecipesMsg pageCmd )

        LabelDesignerPage pageModel ->
            let
                ( newPageModel, pageCmd, _ ) =
                    LabelDesigner.update (LabelDesignerTypes.ReceivedLabelPresets labelPresets) pageModel
            in
            ( { model | page = LabelDesignerPage newPageModel }, Cmd.map LabelDesignerMsg pageCmd )

        _ ->
            ( model, Cmd.none )


{-| Set a notification and schedule its auto-dismiss (except for errors which persist).
-}
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

        -- Success/Info auto-dismiss after 5 seconds; Errors persist
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


handleMenuOutMsg : Menu.OutMsg -> Model -> Cmd Menu.Msg -> ( Model, Cmd Msg )
handleMenuOutMsg outMsg model pageCmd =
    case outMsg of
        MenuTypes.NoOp ->
            ( model, Cmd.map MenuMsg pageCmd )


handleInventoryOutMsg : Inventory.OutMsg -> Model -> Cmd Inventory.Msg -> ( Model, Cmd Msg )
handleInventoryOutMsg outMsg model pageCmd =
    case outMsg of
        InventoryTypes.NoOp ->
            ( model, Cmd.map InventoryMsg pageCmd )

        InventoryTypes.NavigateToBatch batchId ->
            ( model
            , Cmd.batch
                [ Cmd.map InventoryMsg pageCmd
                , Nav.pushUrl model.key ("/batch/" ++ batchId)
                ]
            )

        InventoryTypes.ShowError message ->
            let
                ( newModel, dismissCmd ) =
                    setNotification message Error model
            in
            ( newModel
            , Cmd.batch [ Cmd.map InventoryMsg pageCmd, dismissCmd ]
            )


handleNewBatchOutMsg : NewBatch.OutMsg -> Model -> Cmd NewBatch.Msg -> ( Model, Cmd Msg )
handleNewBatchOutMsg outMsg model pageCmd =
    case outMsg of
        NewBatchTypes.NoOp ->
            ( model, Cmd.map NewBatchMsg pageCmd )

        NewBatchTypes.ShowNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch [ Cmd.map NewBatchMsg pageCmd, dismissCmd ]
            )

        NewBatchTypes.NavigateToHome ->
            ( model
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , Nav.pushUrl model.key "/"
                ]
            )

        NewBatchTypes.NavigateToBatch batchId ->
            ( model
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , Nav.pushUrl model.key ("/batch/" ++ batchId)
                ]
            )

        NewBatchTypes.RefreshBatches ->
            ( model
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , Api.fetchBatches GotBatches
                , Api.fetchIngredients GotIngredients
                ]
            )

        NewBatchTypes.BatchCreatedLocally newBatch batchId ->
            let
                updatedBatches =
                    case model.batches of
                        Loaded batches ->
                            Loaded (newBatch :: batches)

                        other ->
                            other

                updatedModel =
                    { model | batches = updatedBatches }

                ( dispatchedModel, dispatchCmd ) =
                    case updatedBatches of
                        Loaded batches ->
                            dispatchBatchesToPage batches updatedModel

                        _ ->
                            ( updatedModel, Cmd.none )
            in
            ( dispatchedModel
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , dispatchCmd
                , Nav.pushUrl dispatchedModel.key ("/batch/" ++ batchId)
                ]
            )

        NewBatchTypes.RequestSvgToPng request ->
            ( model
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , Ports.requestSvgToPng request
                ]
            )

        NewBatchTypes.RequestTextMeasure request ->
            ( model
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , Ports.requestTextMeasure request
                ]
            )

        NewBatchTypes.RequestFileSelect request ->
            ( model
            , Cmd.batch
                [ Cmd.map NewBatchMsg pageCmd
                , Ports.requestFileSelect request
                ]
            )


handleItemDetailOutMsg : ItemDetail.OutMsg -> Model -> Cmd ItemDetail.Msg -> ( Model, Cmd Msg )
handleItemDetailOutMsg outMsg model pageCmd =
    case outMsg of
        ItemDetailTypes.NoOp ->
            ( model, Cmd.map ItemDetailMsg pageCmd )

        ItemDetailTypes.ShowNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch [ Cmd.map ItemDetailMsg pageCmd, dismissCmd ]
            )

        ItemDetailTypes.RefreshBatches ->
            let
                ( newModel, dismissCmd ) =
                    setNotification "Porción marcada como consumida" Success model
            in
            ( newModel
            , Cmd.batch
                [ Cmd.map ItemDetailMsg pageCmd
                , Api.fetchBatches GotBatches
                , dismissCmd
                ]
            )


handleBatchDetailOutMsg : BatchDetail.OutMsg -> Model -> Cmd BatchDetail.Msg -> ( Model, Cmd Msg )
handleBatchDetailOutMsg outMsg model pageCmd =
    case outMsg of
        BatchDetailTypes.NoOp ->
            ( model, Cmd.map BatchDetailMsg pageCmd )

        BatchDetailTypes.ShowNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch [ Cmd.map BatchDetailMsg pageCmd, dismissCmd ]
            )

        BatchDetailTypes.RequestSvgToPng request ->
            ( model
            , Cmd.batch
                [ Cmd.map BatchDetailMsg pageCmd
                , Ports.requestSvgToPng request
                ]
            )

        BatchDetailTypes.RequestTextMeasure request ->
            ( model
            , Cmd.batch
                [ Cmd.map BatchDetailMsg pageCmd
                , Ports.requestTextMeasure request
                ]
            )


handleHistoryOutMsg : History.OutMsg -> Model -> Cmd History.Msg -> ( Model, Cmd Msg )
handleHistoryOutMsg outMsg model pageCmd =
    case outMsg of
        HistoryTypes.NoOp ->
            ( model, Cmd.map HistoryMsg pageCmd )

        HistoryTypes.ShowError message ->
            let
                ( newModel, dismissCmd ) =
                    setNotification message Error model
            in
            ( newModel
            , Cmd.batch [ Cmd.map HistoryMsg pageCmd, dismissCmd ]
            )


handleContainerTypesOutMsg : ContainerTypes.OutMsg -> Model -> Cmd ContainerTypes.Msg -> ( Model, Cmd Msg )
handleContainerTypesOutMsg outMsg model pageCmd =
    case outMsg of
        ContainerTypesTypes.NoOp ->
            ( model, Cmd.map ContainerTypesMsg pageCmd )

        ContainerTypesTypes.ShowNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch [ Cmd.map ContainerTypesMsg pageCmd, dismissCmd ]
            )

        ContainerTypesTypes.RefreshContainerTypes ->
            ( model
            , Cmd.batch
                [ Cmd.map ContainerTypesMsg pageCmd
                , Api.fetchContainerTypes GotContainerTypes
                ]
            )

        ContainerTypesTypes.RefreshContainerTypesWithNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch
                [ Cmd.map ContainerTypesMsg pageCmd
                , Api.fetchContainerTypes GotContainerTypes
                , dismissCmd
                ]
            )


handleIngredientsOutMsg : Ingredients.OutMsg -> Model -> Cmd Ingredients.Msg -> ( Model, Cmd Msg )
handleIngredientsOutMsg outMsg model pageCmd =
    case outMsg of
        IngredientsTypes.NoOp ->
            ( model, Cmd.map IngredientsMsg pageCmd )

        IngredientsTypes.ShowNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch [ Cmd.map IngredientsMsg pageCmd, dismissCmd ]
            )

        IngredientsTypes.RefreshIngredients ->
            ( model
            , Cmd.batch
                [ Cmd.map IngredientsMsg pageCmd
                , Api.fetchIngredients GotIngredients
                ]
            )

        IngredientsTypes.RefreshIngredientsWithNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch
                [ Cmd.map IngredientsMsg pageCmd
                , Api.fetchIngredients GotIngredients
                , dismissCmd
                ]
            )


handleRecipesOutMsg : Recipes.OutMsg -> Model -> Cmd Recipes.Msg -> ( Model, Cmd Msg )
handleRecipesOutMsg outMsg model pageCmd =
    case outMsg of
        RecipesTypes.NoOp ->
            ( model, Cmd.map RecipesMsg pageCmd )

        RecipesTypes.ShowNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch [ Cmd.map RecipesMsg pageCmd, dismissCmd ]
            )

        RecipesTypes.RefreshRecipes ->
            ( model
            , Cmd.batch
                [ Cmd.map RecipesMsg pageCmd
                , Api.fetchRecipes GotRecipes
                , Api.fetchIngredients GotIngredients
                ]
            )

        RecipesTypes.RefreshRecipesWithNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch
                [ Cmd.map RecipesMsg pageCmd
                , Api.fetchRecipes GotRecipes
                , Api.fetchIngredients GotIngredients
                , dismissCmd
                ]
            )

        RecipesTypes.RequestFileSelect request ->
            ( model
            , Cmd.batch
                [ Cmd.map RecipesMsg pageCmd
                , Ports.requestFileSelect request
                ]
            )


handleLabelDesignerOutMsg : LabelDesigner.OutMsg -> Model -> Cmd LabelDesigner.Msg -> ( Model, Cmd Msg )
handleLabelDesignerOutMsg outMsg model pageCmd =
    case outMsg of
        LabelDesignerTypes.NoOp ->
            ( model, Cmd.map LabelDesignerMsg pageCmd )

        LabelDesignerTypes.ShowNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch [ Cmd.map LabelDesignerMsg pageCmd, dismissCmd ]
            )

        LabelDesignerTypes.RefreshPresets ->
            ( model
            , Cmd.batch
                [ Cmd.map LabelDesignerMsg pageCmd
                , Api.fetchLabelPresets GotLabelPresets
                ]
            )

        LabelDesignerTypes.RefreshPresetsWithNotification notification ->
            let
                ( newModel, dismissCmd ) =
                    setNotification notification.message notification.notificationType model
            in
            ( newModel
            , Cmd.batch
                [ Cmd.map LabelDesignerMsg pageCmd
                , Api.fetchLabelPresets GotLabelPresets
                , dismissCmd
                ]
            )

        LabelDesignerTypes.RequestTextMeasure request ->
            ( model
            , Cmd.batch
                [ Cmd.map LabelDesignerMsg pageCmd
                , Ports.requestTextMeasure request
                ]
            )

        LabelDesignerTypes.RequestSvgToPng request ->
            ( model
            , Cmd.batch
                [ Cmd.map LabelDesignerMsg pageCmd
                , Ports.requestSvgToPng request
                ]
            )

        LabelDesignerTypes.RequestInitPinchZoom config ->
            ( model
            , Cmd.batch
                [ Cmd.map LabelDesignerMsg pageCmd
                , Ports.initPinchZoom config
                ]
            )

        LabelDesignerTypes.RequestSetPinchZoom config ->
            ( model
            , Cmd.batch
                [ Cmd.map LabelDesignerMsg pageCmd
                , Ports.setPinchZoom config
                ]
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.receivePngResult GotPngResult
        , Ports.receiveTextMeasureResult GotTextMeasureResult
        , Ports.receivePinchZoomUpdate GotPinchZoomUpdate
        , Ports.receiveFileSelectResult GotFileSelectResult
        ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "FrostByte"
    , body =
        [ div [ class "min-h-screen bg-gray-100" ]
            [ Components.viewHeader model.route model.mobileMenuOpen model.configDropdownOpen ToggleMobileMenu ToggleConfigDropdown
            , Components.viewNotification model.notification DismissNotification
            , Components.viewPrintingProgress model.printingProgress
            , main_ [ class "container mx-auto px-4 py-8" ]
                [ if not (allSettled model) then
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
        MenuPage pageModel ->
            Html.map MenuMsg (Menu.view pageModel)

        InventoryPage pageModel ->
            Html.map InventoryMsg (Inventory.view pageModel)

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

        LabelDesignerPage pageModel ->
            Html.map LabelDesignerMsg (LabelDesigner.view pageModel)

        NotFoundPage ->
            NotFound.view
