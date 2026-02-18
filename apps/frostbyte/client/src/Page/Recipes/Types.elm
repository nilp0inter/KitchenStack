module Page.Recipes.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Components.MarkdownEditor as MarkdownEditor
import Http
import Ports
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
    , detailsEditor : MarkdownEditor.Model
    , viewMode : ViewMode
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
    | SaveRecipe
    | StartCreate
    | EditRecipe Recipe
    | CancelEdit
    | DeleteRecipe String
    | ConfirmDelete String
    | CancelDelete
    | RecipeSaved (Result Http.Error ())
    | RecipeDeleted (Result Http.Error ())
    | HideSuggestions
    | IngredientKeyDown String
    | DetailsEditorMsg MarkdownEditor.Msg
    | ReceivedIngredients (List Ingredient)
    | ReceivedContainerTypes (List ContainerType)
    | ReceivedRecipes (List Recipe)
    | ReceivedLabelPresets (List LabelPreset)
    | SelectImage
    | GotImageResult Ports.FileSelectResult
    | RemoveImage


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshRecipes
    | RefreshRecipesWithNotification Notification
    | RequestFileSelect Ports.FileSelectRequest
