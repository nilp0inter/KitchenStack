module Data.ContainerType exposing (empty)

import Types exposing (ContainerTypeForm)


empty : ContainerTypeForm
empty =
    { name = ""
    , servingsPerUnit = ""
    , editing = Nothing
    }
