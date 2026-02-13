module Data.Recipe exposing (empty)

import Types exposing (RecipeForm)


empty : RecipeForm
empty =
    { name = ""
    , selectedIngredients = []
    , ingredientInput = ""
    , defaultPortions = "1"
    , defaultContainerId = ""
    , defaultLabelPreset = ""
    , editing = Nothing
    , details = ""
    , image = Nothing
    }
