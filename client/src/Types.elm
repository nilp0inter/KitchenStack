module Types exposing
    ( BatchDetailData
    , BatchForm
    , BatchSummary
    , Category
    , ContainerType
    , ContainerTypeForm
    , CreateBatchResponse
    , Flags
    , HistoryPoint
    , Notification
    , NotificationType(..)
    , PortionDetail
    , PortionInBatch
    , PortionPrintData
    , PrintingProgress
    , emptyBatchForm
    , emptyContainerTypeForm
    )


type alias Flags =
    { currentDate : String
    }


type alias BatchSummary =
    { batchId : String
    , name : String
    , categoryId : String
    , containerId : String
    , ingredients : String
    , batchCreatedAt : String
    , expiryDate : String
    , frozenCount : Int
    , consumedCount : Int
    , totalCount : Int
    }


type alias PortionDetail =
    { portionId : String
    , batchId : String
    , createdAt : String
    , expiryDate : String
    , status : String
    , consumedAt : Maybe String
    , name : String
    , categoryId : String
    , containerId : String
    , ingredients : String
    }


type alias Category =
    { name : String
    , safeDays : Int
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
    , categoryId : String
    , containerId : String
    , ingredients : String
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
    , categoryId = ""
    , containerId = ""
    , ingredients = ""
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
