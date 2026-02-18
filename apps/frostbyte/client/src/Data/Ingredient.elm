module Data.Ingredient exposing (empty)

import Types exposing (IngredientForm)


empty : IngredientForm
empty =
    { name = ""
    , expireDays = ""
    , bestBeforeDays = ""
    , editing = Nothing
    }
