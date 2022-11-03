module Endpoint exposing (Endpoint, activeSessions, clusterf0, clusterf1, decoder, encode, endpoint, imagesEndpoint, toString)

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)


{-| An API Endpoint
-}
type Endpoint
    = Endpoint String



-- ENDPOINTS


clusterf0 : Endpoint
clusterf0 =
    Endpoint "json/clusterf0.json"


clusterf1 : Endpoint
clusterf1 =
    Endpoint "json/clusterf1.json"


activeSessions : Endpoint
activeSessions =
    Endpoint "api/active"


imagesEndpoint : Endpoint
imagesEndpoint =
    Endpoint "api/images"



-- HELPERS


endpoint : String -> Endpoint
endpoint url =
    Endpoint url


toString : Endpoint -> String
toString (Endpoint str) =
    str


encode : Endpoint -> Value
encode (Endpoint str) =
    Encode.string str


decoder : Decoder Endpoint
decoder =
    Decode.map Endpoint Decode.string
