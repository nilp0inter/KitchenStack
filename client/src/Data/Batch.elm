module Data.Batch exposing (empty)

import Types exposing (BatchForm)


empty : String -> BatchForm
empty currentDate =
    { name = ""
    , selectedIngredients = []
    , ingredientInput = ""
    , containerId = ""
    , quantity = "1"
    , createdAt = currentDate
    , expiryDate = ""
    , details = ""
    , image = Nothing
    }
