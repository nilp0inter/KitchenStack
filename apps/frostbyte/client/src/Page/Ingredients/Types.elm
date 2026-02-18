module Page.Ingredients.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Http
import Types exposing (..)


type alias Model =
    { ingredients : List Ingredient
    , form : IngredientForm
    , loading : Bool
    , deleteConfirm : Maybe String
    , viewMode : ViewMode
    }


type Msg
    = GotIngredients (Result Http.Error (List Ingredient))
    | FormNameChanged String
    | FormExpireDaysChanged String
    | FormBestBeforeDaysChanged String
    | SaveIngredient
    | StartCreate
    | EditIngredient Ingredient
    | CancelEdit
    | DeleteIngredient String
    | ConfirmDelete String
    | CancelDelete
    | IngredientSaved (Result Http.Error ())
    | IngredientDeleted (Result Http.Error ())
    | ReceivedIngredients (List Ingredient)


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshIngredients
    | RefreshIngredientsWithNotification Notification
