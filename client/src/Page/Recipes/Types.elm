module Page.Recipes.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Http
import Types exposing (..)


type alias Model =
    { recipes : List Recipe
    , ingredients : List Ingredient
    , containerTypes : List ContainerType
    , labelPresets : List LabelPreset
    , form : RecipeForm
    , loading : Bool
    , deleteConfirm : Maybe String
    , showSuggestions : Bool
    }


type Msg
    = GotRecipes (Result Http.Error (List Recipe))
    | FormNameChanged String
    | FormIngredientInputChanged String
    | AddIngredient String
    | RemoveIngredient String
    | FormPortionsChanged String
    | FormContainerChanged String
    | FormLabelPresetChanged String
    | FormDetailsChanged String
    | SaveRecipe
    | EditRecipe Recipe
    | CancelEdit
    | DeleteRecipe String
    | ConfirmDelete String
    | CancelDelete
    | RecipeSaved (Result Http.Error ())
    | RecipeDeleted (Result Http.Error ())
    | HideSuggestions
    | IngredientKeyDown String


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshRecipes
    | RefreshRecipesWithNotification Notification
