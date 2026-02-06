module Types exposing
    ( BatchDetailData
    , BatchForm
    , BatchSummary
    , ContainerType
    , ContainerTypeForm
    , CreateBatchResponse
    , Flags
    , HistoryPoint
    , Ingredient
    , IngredientForm
    , Notification
    , NotificationType(..)
    , PortionDetail
    , PortionInBatch
    , PortionPrintData
    , PrintingProgress
    , Recipe
    , RecipeForm
    , SelectedIngredient
    , emptyBatchForm
    , emptyContainerTypeForm
    , emptyIngredientForm
    , emptyRecipeForm
    )


type alias Flags =
    { currentDate : String
    }


type alias BatchSummary =
    { batchId : String
    , name : String
    , containerId : String
    , bestBeforeDate : Maybe String
    , batchCreatedAt : String
    , expiryDate : String
    , frozenCount : Int
    , consumedCount : Int
    , totalCount : Int
    , ingredients : String
    }


type alias PortionDetail =
    { portionId : String
    , batchId : String
    , createdAt : String
    , expiryDate : String
    , status : String
    , consumedAt : Maybe String
    , name : String
    , containerId : String
    , bestBeforeDate : Maybe String
    , ingredients : String
    }


type alias Ingredient =
    { name : String
    , expireDays : Maybe Int
    , bestBeforeDays : Maybe Int
    }


type alias IngredientForm =
    { name : String
    , expireDays : String
    , bestBeforeDays : String
    , editing : Maybe String
    }


type alias SelectedIngredient =
    { name : String
    , isNew : Bool
    }


type alias ContainerType =
    { name : String
    , servingsPerUnit : Float
    }


type alias ContainerTypeForm =
    { name : String
    , servingsPerUnit : String
    , editing : Maybe String
    }


type alias BatchForm =
    { name : String
    , selectedIngredients : List SelectedIngredient
    , ingredientInput : String
    , containerId : String
    , quantity : String
    , createdAt : String
    , expiryDate : String
    }


type alias CreateBatchResponse =
    { batchId : String
    , portionIds : List String
    }


type alias HistoryPoint =
    { date : String
    , added : Int
    , consumed : Int
    , frozenTotal : Int
    }


type alias Notification =
    { message : String
    , notificationType : NotificationType
    }


type alias PrintingProgress =
    { total : Int
    , completed : Int
    , failed : Int
    }


type alias BatchDetailData =
    { batch : BatchSummary
    , portions : List PortionInBatch
    }


type alias PortionInBatch =
    { portionId : String
    , status : String
    , createdAt : String
    , expiryDate : String
    , consumedAt : Maybe String
    }


type NotificationType
    = Success
    | Error
    | Info


type alias PortionPrintData =
    { portionId : String
    , name : String
    , ingredients : String
    , containerId : String
    , expiryDate : String
    }


emptyBatchForm : String -> BatchForm
emptyBatchForm currentDate =
    { name = ""
    , selectedIngredients = []
    , ingredientInput = ""
    , containerId = ""
    , quantity = "1"
    , createdAt = currentDate
    , expiryDate = ""
    }


emptyContainerTypeForm : ContainerTypeForm
emptyContainerTypeForm =
    { name = ""
    , servingsPerUnit = ""
    , editing = Nothing
    }


emptyIngredientForm : IngredientForm
emptyIngredientForm =
    { name = ""
    , expireDays = ""
    , bestBeforeDays = ""
    , editing = Nothing
    }


type alias Recipe =
    { name : String
    , defaultPortions : Int
    , defaultContainerId : Maybe String
    , ingredients : String
    }


type alias RecipeForm =
    { name : String
    , selectedIngredients : List SelectedIngredient
    , ingredientInput : String
    , defaultPortions : String
    , defaultContainerId : String
    , editing : Maybe String
    }


emptyRecipeForm : RecipeForm
emptyRecipeForm =
    { name = ""
    , selectedIngredients = []
    , ingredientInput = ""
    , defaultPortions = "1"
    , defaultContainerId = ""
    , editing = Nothing
    }
