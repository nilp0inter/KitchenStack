module Page.NewBatch exposing
    ( Model
    , Msg
    , OutMsg(..)
    , init
    , update
    , view
    )

import Api
import Html exposing (..)
import Html.Attributes as Attr exposing (class, disabled, href, id, placeholder, required, selected, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as Decode
import Random
import Types exposing (..)
import UUID exposing (UUID)


type alias Model =
    { form : BatchForm
    , ingredients : List Ingredient
    , containerTypes : List ContainerType
    , recipes : List Recipe
    , loading : Bool
    , printWithSave : Bool
    , printingProgress : Maybe PrintingProgress
    , showSuggestions : Bool
    , showRecipeSuggestions : Bool
    , expiryRequired : Bool
    }


type Msg
    = FormNameChanged String
    | FormIngredientInputChanged String
    | AddIngredient String
    | RemoveIngredient String
    | FormContainerChanged String
    | FormQuantityChanged String
    | FormCreatedAtChanged String
    | FormExpiryDateChanged String
    | SubmitBatchOnly
    | SubmitBatchWithPrint
    | GotUuidsForBatch (List UUID)
    | BatchCreated (Result Http.Error CreateBatchResponse)
    | PrintResult String (Result Http.Error ())
    | HideSuggestions
    | HideRecipeSuggestions
    | IngredientKeyDown String
    | SelectRecipe Recipe


type OutMsg
    = NoOp
    | ShowNotification Notification
    | NavigateToHome
    | NavigateToBatch String
    | RefreshBatches


init : String -> List Ingredient -> List ContainerType -> List Recipe -> ( Model, Cmd Msg )
init currentDate ingredients containerTypes recipes =
    let
        form =
            emptyBatchForm currentDate

        formWithDefaults =
            { form
                | containerId =
                    List.head containerTypes
                        |> Maybe.map .name
                        |> Maybe.withDefault ""
            }
    in
    ( { form = formWithDefaults
      , ingredients = ingredients
      , containerTypes = containerTypes
      , recipes = recipes
      , loading = False
      , printWithSave = True
      , printingProgress = Nothing
      , showSuggestions = False
      , showRecipeSuggestions = False
      , expiryRequired = False
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        FormNameChanged name ->
            let
                form =
                    model.form

                shouldShowRecipeSuggestions =
                    String.length name >= 2
            in
            ( { model
                | form = { form | name = name }
                , showRecipeSuggestions = shouldShowRecipeSuggestions
              }
            , Cmd.none
            , NoOp
            )

        FormIngredientInputChanged input ->
            let
                form =
                    model.form

                shouldShowSuggestions =
                    String.length input >= 1
            in
            ( { model
                | form = { form | ingredientInput = input }
                , showSuggestions = shouldShowSuggestions
              }
            , Cmd.none
            , NoOp
            )

        AddIngredient ingredientName ->
            let
                trimmedName =
                    String.trim (String.toLower ingredientName)

                form =
                    model.form

                alreadySelected =
                    List.any (\i -> String.toLower i.name == trimmedName) form.selectedIngredients

                isExisting =
                    List.any (\i -> String.toLower i.name == trimmedName) model.ingredients

                newSelectedIngredient =
                    { name = trimmedName
                    , isNew = not isExisting
                    }

                newSelectedIngredients =
                    if trimmedName /= "" && not alreadySelected then
                        form.selectedIngredients ++ [ newSelectedIngredient ]

                    else
                        form.selectedIngredients

                -- Check if any selected ingredient has expire_days
                hasExpiryInfo =
                    List.any
                        (\sel ->
                            List.any
                                (\ing ->
                                    String.toLower ing.name == String.toLower sel.name && ing.expireDays /= Nothing
                                )
                                model.ingredients
                        )
                        newSelectedIngredients
            in
            ( { model
                | form =
                    { form
                        | selectedIngredients = newSelectedIngredients
                        , ingredientInput = ""
                    }
                , showSuggestions = False
                , expiryRequired = not hasExpiryInfo
              }
            , Cmd.none
            , NoOp
            )

        RemoveIngredient ingredientName ->
            let
                form =
                    model.form

                newSelectedIngredients =
                    List.filter (\i -> i.name /= ingredientName) form.selectedIngredients

                -- Check if any remaining ingredient has expire_days
                hasExpiryInfo =
                    List.any
                        (\sel ->
                            List.any
                                (\ing ->
                                    String.toLower ing.name == String.toLower sel.name && ing.expireDays /= Nothing
                                )
                                model.ingredients
                        )
                        newSelectedIngredients
            in
            ( { model
                | form = { form | selectedIngredients = newSelectedIngredients }
                , expiryRequired = not hasExpiryInfo && not (List.isEmpty newSelectedIngredients)
              }
            , Cmd.none
            , NoOp
            )

        FormContainerChanged containerId ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | containerId = containerId } }, Cmd.none, NoOp )

        FormQuantityChanged quantity ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | quantity = quantity } }, Cmd.none, NoOp )

        FormCreatedAtChanged createdAt ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | createdAt = createdAt } }, Cmd.none, NoOp )

        FormExpiryDateChanged expiryDate ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | expiryDate = expiryDate } }, Cmd.none, NoOp )

        SubmitBatchOnly ->
            if List.isEmpty model.form.selectedIngredients then
                ( model, Cmd.none, ShowNotification { message = "Debes añadir al menos un ingrediente", notificationType = Error } )

            else if model.expiryRequired && model.form.expiryDate == "" then
                ( model, Cmd.none, ShowNotification { message = "Debes indicar fecha de caducidad (ningún ingrediente tiene días definidos)", notificationType = Error } )

            else
                let
                    quantity =
                        Maybe.withDefault 1 (String.toInt model.form.quantity)

                    uuidCount =
                        1 + quantity
                in
                ( { model | loading = True, printWithSave = False }
                , Random.generate GotUuidsForBatch (Random.list uuidCount UUID.generator)
                , NoOp
                )

        SubmitBatchWithPrint ->
            if List.isEmpty model.form.selectedIngredients then
                ( model, Cmd.none, ShowNotification { message = "Debes añadir al menos un ingrediente", notificationType = Error } )

            else if model.expiryRequired && model.form.expiryDate == "" then
                ( model, Cmd.none, ShowNotification { message = "Debes indicar fecha de caducidad (ningún ingrediente tiene días definidos)", notificationType = Error } )

            else
                let
                    quantity =
                        Maybe.withDefault 1 (String.toInt model.form.quantity)

                    uuidCount =
                        1 + quantity
                in
                ( { model | loading = True, printWithSave = True }
                , Random.generate GotUuidsForBatch (Random.list uuidCount UUID.generator)
                , NoOp
                )

        GotUuidsForBatch uuids ->
            case uuids of
                batchUuid :: portionUuids ->
                    ( model
                    , Api.createBatch model.form batchUuid portionUuids BatchCreated
                    , NoOp
                    )

                [] ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Failed to generate UUIDs", notificationType = Error }
                    )

        BatchCreated result ->
            case result of
                Ok response ->
                    if model.printWithSave then
                        let
                            quantity =
                                List.length response.portionIds

                            ingredientsText =
                                String.join ", " (List.map .name model.form.selectedIngredients)

                            printData =
                                List.map
                                    (\portionId ->
                                        { portionId = portionId
                                        , name = model.form.name
                                        , ingredients = ingredientsText
                                        , containerId = model.form.containerId
                                        , expiryDate = model.form.expiryDate
                                        }
                                    )
                                    response.portionIds

                            printCommands =
                                List.map (\data -> Api.printLabel data PrintResult) printData

                            currentDate =
                                model.form.createdAt
                        in
                        ( { model
                            | form = emptyBatchForm currentDate
                            , loading = False
                            , printingProgress = Just { total = quantity, completed = 0, failed = 0 }
                            , expiryRequired = False
                          }
                        , Cmd.batch printCommands
                        , NavigateToHome
                        )

                    else
                        let
                            currentDate =
                                model.form.createdAt
                        in
                        ( { model | form = emptyBatchForm currentDate, loading = False, expiryRequired = False }
                        , Cmd.none
                        , NavigateToBatch response.batchId
                        )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al crear lote. Verifica que los ingredientes tienen días de caducidad o especifica una fecha manual.", notificationType = Error }
                    )

        PrintResult _ result ->
            let
                updateProgress progress =
                    case result of
                        Ok _ ->
                            { progress | completed = progress.completed + 1 }

                        Err _ ->
                            { progress | failed = progress.failed + 1 }

                newProgress =
                    Maybe.map updateProgress model.printingProgress

                allDone =
                    case newProgress of
                        Just p ->
                            p.completed + p.failed >= p.total

                        Nothing ->
                            True

                outMsg =
                    if allDone then
                        case newProgress of
                            Just p ->
                                if p.failed > 0 then
                                    ShowNotification { message = String.fromInt p.completed ++ " labels printed, " ++ String.fromInt p.failed ++ " failed", notificationType = Error }

                                else
                                    ShowNotification { message = String.fromInt p.completed ++ " labels printed successfully!", notificationType = Success }

                            Nothing ->
                                NoOp

                    else
                        NoOp

                finalProgress =
                    if allDone then
                        Nothing

                    else
                        newProgress
            in
            ( { model | printingProgress = finalProgress }
            , Cmd.none
            , if allDone then
                RefreshBatches

              else
                outMsg
            )

        HideSuggestions ->
            ( { model | showSuggestions = False }, Cmd.none, NoOp )

        HideRecipeSuggestions ->
            ( { model | showRecipeSuggestions = False }, Cmd.none, NoOp )

        SelectRecipe recipe ->
            let
                -- Parse ingredients from recipe.ingredients string
                ingredientNames =
                    String.split ", " recipe.ingredients
                        |> List.filter (\s -> String.trim s /= "")

                selectedIngredients =
                    List.map
                        (\name ->
                            { name = name
                            , isNew = not (List.any (\i -> String.toLower i.name == String.toLower name) model.ingredients)
                            }
                        )
                        ingredientNames

                -- Check if any ingredient has expire_days
                hasExpiryInfo =
                    List.any
                        (\sel ->
                            List.any
                                (\ing ->
                                    String.toLower ing.name == String.toLower sel.name && ing.expireDays /= Nothing
                                )
                                model.ingredients
                        )
                        selectedIngredients

                containerId =
                    Maybe.withDefault model.form.containerId recipe.defaultContainerId

                form =
                    model.form
            in
            ( { model
                | form =
                    { form
                        | name = recipe.name
                        , selectedIngredients = selectedIngredients
                        , quantity = String.fromInt recipe.defaultPortions
                        , containerId = containerId
                    }
                , showRecipeSuggestions = False
                , expiryRequired = not hasExpiryInfo && not (List.isEmpty selectedIngredients)
              }
            , Cmd.none
            , NoOp
            )

        IngredientKeyDown key ->
            if key == "Enter" || key == "," then
                let
                    trimmedInput =
                        String.trim model.form.ingredientInput
                in
                if trimmedInput /= "" then
                    update (AddIngredient trimmedInput) model

                else
                    ( model, Cmd.none, NoOp )

            else
                ( model, Cmd.none, NoOp )


view : Model -> Html Msg
view model =
    div [ class "max-w-2xl mx-auto" ]
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
        [ div [ class "flex items-center justify-between" ]
            [ span [ class "font-medium text-gray-900" ] [ text recipe.name ]
            , span [ class "text-xs bg-frost-100 text-frost-700 px-2 py-0.5 rounded" ] [ text "Receta" ]
            ]
        , div [ class "text-sm text-gray-500 mt-1" ]
            [ text
                (if String.length recipe.ingredients > 50 then
                    String.left 50 recipe.ingredients ++ "..."

                 else
                    recipe.ingredients
                )
            ]
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
