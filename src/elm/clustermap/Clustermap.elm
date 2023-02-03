module Clustermap exposing (MapSettings, Model, Msg(..), init, update, view, viewUsedImacs)

{-| This Clustermap module makes it possible to display multiple clustermaps
without a lot of duplicate code. It is setup in such a way that it will work
with any map and any amount of computers.
-}

import Asset exposing (Image)
import Bootstrap.Button as Button
import Bootstrap.Popover as Popover
import Endpoint exposing (Endpoint, imagesEndpoint)
import Html exposing (Html, a, div, img, p, text)
import Html.Attributes exposing (class, href, id, src, style, target)
import Html.Keyed as Keyed
import Http exposing (Error)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Field as Field
import Maybe
import Platform.Cmd
import Time
import Asset exposing (image)
import Html.Attributes exposing (classList)



-- MODEL

{-| Tracks the state of a session request.
-}
type SessionRequest
    = Failure Http.Error
    | Loading
    | Success (List Session)


{-| Tracks the state of a host request.
-}
type HostRequest
    = HostFailure Http.Error
    | HostLoading
    | HostSuccess HostModel

{-| Tracks the state of an image request.
-}
type ImageRequest
    = ImageFailure Http.Error
    | ImageLoading
    | ImageSuccess (List UserImage)

{-| Contains the settings used to render the map.
These are passed to the init function.
The sizes are all in pixels.
-}
type alias MapSettings =
    { height : Int
    , width : Int
    , activeIconSize : Int
    , emptyIconSize : Int
    }


{-| Holds the mapSettings loaded from the host json and the list of hosts. The
mapSettings width and height are needed to recalculate the icon positions if the
map size changes. The IconSize values are not used.
-}
type alias HostModel =
    { mapSettings : MapSettings
    , hostList : List Host
    }


{-| Defines one host. Position is used as ( left, top ) in pixels.
-}
type alias Host =
    { id : String
    , position : ( Int, Int )
    , popState : Popover.State
    }


{-| Defines an active session. The host field should match one of the host id's
in the hostList. If it doesn't the session is not displayed. The username is
used in the display and to find the profile picture.
-}
type alias Session =
    { username : String
    , host : String
    , imageSrc : Image
    , alive : Bool
    , sessionType : String
    }

type alias UserImage =
    { id : Int
    , username : String
    , image : ImageJson
    }

type alias ImageJson =
    { link : Image
    , versions : ImageVersions
    }

type alias ImageVersions =
    { micro : Image
    , small : Image
    , medium : Image
    , large : Image
    }

type alias Model =
    { hostEndpoint : Endpoint
    , sessionEndpoint : Endpoint
    , mapImage : Asset.Image
    , mapSettings : MapSettings
    , activeList : List Session
    , hostModel : Maybe HostModel
    , imageList : List UserImage
    , reqS : SessionRequest
    , reqH : HostRequest
    , reqI : ImageRequest
    }



-- INIT


init : Endpoint -> Endpoint -> Image -> MapSettings -> ( Model, Cmd Msg )
init hostEndpoint sessionEndpoint image mapsettings =
    ( { hostEndpoint = hostEndpoint
      , sessionEndpoint = sessionEndpoint
      , mapImage = image
      , mapSettings = mapsettings
      , activeList = []
      , hostModel = Nothing
      , imageList = []
      , reqS = Loading
      , reqH = HostLoading
      , reqI = ImageLoading
      }
    , Platform.Cmd.batch [ getHosts hostEndpoint, getImages imagesEndpoint ]
    )



-- UPDATE


type Msg
    = GotSessions (Result Error (List Session))
    | GotHosts (Result Error HostModel)
    | GotImages (Result Error (List UserImage))
    | FetchSessions Time.Posix
    | PopoverMsg String Popover.State


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSessions result ->
            case result of
                Ok sessionlist ->
                    ( { model | activeList = sessionlist, reqS = Success sessionlist }
                    , Cmd.none
                    )

                Err err ->
                    ( { model | reqS = Failure err }
                    , Cmd.none
                    )

        GotHosts result ->
            case result of
                Ok hostmodel ->
                    ( { model | hostModel = Just hostmodel, reqH = HostSuccess hostmodel }
                    , Cmd.none
                    )

                Err err ->
                    ( { model | reqH = HostFailure err }
                    , Cmd.none
                    )
        GotImages result ->
            case result of
                Ok imagelist ->
                    ( { model | imageList = imagelist, reqI = ImageSuccess imagelist }
                    , getActiveSessions model.sessionEndpoint model.activeList imagelist
                    )

                Err err ->
                    ( { model | reqI = ImageFailure err }
                    , Cmd.none
                    )

        FetchSessions _ ->
            ( model
            , getActiveSessions model.sessionEndpoint model.activeList model.imageList
            )

        PopoverMsg host state ->
            let
                updatePopState session =
                    if String.contains host session.id then
                        { session | popState = state }

                    else
                        session
            in
            let
                newhostModel =
                    case model.hostModel of
                        Nothing ->
                            Nothing

                        Just hmodel ->
                            Just { hmodel | hostList = List.map updatePopState hmodel.hostList }
            in
            case newhostModel of
                Nothing ->
                    ( { model | hostModel = newhostModel }, Cmd.none )

                Just newhmodel ->
                    ( { model | hostModel = Just newhmodel, reqH = HostSuccess newhmodel }, Cmd.none )


-- VIEW


{-| The view is rendered based on if the http request for hosts and sessions
succeed. If they don't the view can sometimes be rendered using "old" data. In
that case a warning is displayed. The case where the hostrequest fails but we
still have a hostmodel shouldn't happen because the hostrequest is done only
once. It is still handled just to be sure.
-}
view : Model -> Html Msg
view model =
    case model.reqH of
        HostFailure err ->
            case model.hostModel of
                Nothing ->
                    div []
                        [ p [] [ text <| "Error retrieving hosts, can't show map. Error: " ++ httpErrorString err ]
                        ]

                Just hostmodel ->
                    case model.reqS of
                        Failure _ ->
                            div []
                                [ p [] [ text "Error retrieving sessions, map might be outdated." ]
                                , viewMap model model.activeList hostmodel
                                ]

                        Loading ->
                            text "Loading Sessions..."

                        Success sessionlist ->
                            viewMap model sessionlist hostmodel

        HostLoading ->
            text "Loading Hosts..."

        HostSuccess hostmodel ->
            case model.reqS of
                Failure _ ->
                    div []
                        [ p [] [ text "Error retrieving sessions, map might be outdated." ]
                        , viewMap model model.activeList hostmodel
                        ]

                Loading ->
                    text "Loading Sessions..."

                Success sessionlist ->
                    case model.reqI of
                        ImageFailure _ ->
                            div []
                                [ p [] [ text "Error retrieving images, sorry :(" ]
                                , viewMap model sessionlist hostmodel
                                ]

                        ImageLoading ->
                            text "Loading Images..."

                        ImageSuccess _ ->
                            viewMap model sessionlist hostmodel


{-| Renders the map and all the icons.
-}
viewMap : Model -> List Session -> HostModel -> Html Msg
viewMap model sessionlist hostmodel =
    Keyed.node "div"
        [ style "position" "relative" ]
        (( Asset.toString model.mapImage
         , img
            [ src (Asset.toString model.mapImage)
            , style "position" "relative"
            , style "height" <| String.fromInt model.mapSettings.height ++ "px"
            , style "width" <| String.fromInt model.mapSettings.width ++ "px"
            ]
            []
         )
            :: viewIcons model sessionlist hostmodel
        )


{-| Renders the list of icons with their correct positions which will be
displayed on the map.
-}
viewIcons : Model -> List Session -> HostModel -> List ( String, Html Msg )
viewIcons model sessionlist hostmodel =
    List.map (viewKeyedIcon model sessionlist hostmodel.mapSettings) hostmodel.hostList


{-| Keys the icon for faster dom rendering.
-}
viewKeyedIcon : Model -> List Session -> MapSettings -> Host -> ( String, Html Msg )
viewKeyedIcon model sessionlist hostmapsettings host =
    ( host.id, viewIcon model sessionlist hostmapsettings host )


{-| Renders the icon and gives it correct position values. Can be either an
empty host icon or an active session icon.
-}
viewIcon : Model -> List Session -> MapSettings -> Host -> Html Msg
viewIcon model sessionlist hostmapsettings host =
    let
        maybeSession =
            List.head (List.filter (hostFilter host.id) sessionlist)
    in
    let
        offset =
            case maybeSession of
                Nothing ->
                    model.mapSettings.emptyIconSize // 2

                Just session ->
                    if session.alive then model.mapSettings.activeIconSize // 2 else model.mapSettings.emptyIconSize // 2
    in
    div
        [ class "imac-location"
        , style "left"
            <| String.fromInt ((calculateLeft model hostmapsettings
            <| Tuple.first host.position) - offset) ++ "px"
        , style "top"
            <| String.fromInt ((calculateTop model hostmapsettings
            <| Tuple.second host.position) - offset) ++ "px"
        ]
        (case maybeSession of
            Nothing ->
                [ Popover.config
                    (Button.button
                        [ Button.attrs
                            <| id (hostToId host.id)
                            :: Popover.onHover host.popState (PopoverMsg host.id)
                        ]
                        [ Asset.emptyHost model.mapSettings.emptyIconSize ]
                    )
                    |> Popover.top
                    |> Popover.content [] [ text (hostToId host.id) ]
                    |> Popover.view host.popState
                ]

            Just session ->
                if session.alive then
                    [ Popover.config
                        (Button.button
                            [ Button.attrs
                                <| id (hostToId host.id)
                                :: Popover.onHover host.popState (PopoverMsg host.id)
                            ]
                            [ a [ href ("https://profile.intra.42.fr/users/" ++ session.username), target "_blank" ]
                                [ img
                                    [ src (Asset.toString session.imageSrc)
                                    , classList [
                                        ( "round-img", True )
                                        , ( "session-" ++ session.sessionType, True )
                                    ]
                                    , style "width"
                                        <| String.fromInt model.mapSettings.activeIconSize
                                    , style "height"
                                        <| String.fromInt model.mapSettings.activeIconSize
                                    ]
                                    []
                                ]
                            ]
                        )
                        |> Popover.top
                        |> Popover.title [] [ text session.username ]
                        |> Popover.content [] [ text (hostToId host.id) ]
                        |> Popover.view host.popState
                    ]
                else
                    [ Popover.config
                        (Button.button
                            [ Button.attrs
                                <| id (hostToId host.id)
                                :: Popover.onHover host.popState (PopoverMsg host.id)
                            ]
                            [ Asset.deadHost model.mapSettings.emptyIconSize ]
                        )
                        |> Popover.top
                        |> Popover.content [] [ text (hostToId host.id ++ "") ]
                        |> Popover.view host.popState
                    ]
        )


{-| Renders a text element containing the amount of used imacs and total imacs
in "42/120" format.
-}
viewUsedImacs : Model -> Html Msg
viewUsedImacs model =
    let
        hlist =
            case model.hostModel of
                Nothing ->
                    []

                Just hmodel ->
                    hmodel.hostList
    in
    let
        totalImacs =
            String.fromInt
                <| List.length hlist - (List.length <| List.filter (deadHostListFilter hlist) model.activeList)

        usedImacs =
            String.fromInt
                <| List.length
                <| List.filter (hostListFilter hlist) model.activeList
    in
    text (usedImacs ++ "/" ++ totalImacs)



-- HOST HELPERS


{-| Recalculates the left position value using the base map size (from the
hostModel) and the actual mapsize.
-}
calculateLeft : Model -> MapSettings -> Int -> Int
calculateLeft model hostmapsettings left =
    round
        <| (toFloat left / toFloat hostmapsettings.width) * toFloat model.mapSettings.width


{-| Recalculates the top position value using the base map size (from the
hostModel) and the actual mapsize.
-}
calculateTop : Model -> MapSettings -> Int -> Int
calculateTop model hostmapsettings top =
    round
        <| (toFloat top / toFloat hostmapsettings.height) * toFloat model.mapSettings.height


hostListFilter : List Host -> Session -> Bool
hostListFilter hostlist session =
    case List.head <| List.filter (sessionFilter session) hostlist of
        Nothing ->
            False

        Just _ ->
            True



deadHostListFilter : List Host -> Session -> Bool
deadHostListFilter hostlist session =
    case List.head <| List.filter (deadHostSessionFilter session) hostlist of
        Nothing ->
            False

        Just _ ->
            True

deadHostSessionFilter : Session -> Host -> Bool
deadHostSessionFilter session host =
    not session.alive && String.contains session.host host.id

sessionFilter : Session -> Host -> Bool
sessionFilter session host =
    session.alive && String.contains session.host host.id

hostFilter : String -> Session -> Bool
hostFilter host session =
    String.contains host session.host

hostToId : String -> String
hostToId host =
    Maybe.withDefault host (List.head (String.split "." host))



-- HTTP


getHosts : Endpoint -> Cmd Msg
getHosts endpoint =
    Http.get
        { url = Endpoint.toString endpoint
        , expect = Http.expectJson GotHosts hostModelDecoder
        }


getActiveSessions : Endpoint -> (List Session) -> (List UserImage) -> Cmd Msg
getActiveSessions endpoint sessionlist userimagelist=
    Http.get
        { url = Endpoint.toString endpoint
        , expect = Http.expectJson GotSessions (sessionListDecoder sessionlist userimagelist)
        }

getImages : Endpoint -> Cmd Msg
getImages endpoint =
    Http.get
        { url = Endpoint.toString endpoint
        , expect = Http.expectJson GotImages imageRequestListDecoder
        }



httpErrorString : Error -> String
httpErrorString error =
    case error of
        Http.BadUrl text ->
            "Bad Url: " ++ text

        Http.Timeout ->
            "Http Timeout"

        Http.NetworkError ->
            "Network Error"

        Http.BadStatus response ->
            "Bad Http Status: " ++ String.fromInt response

        Http.BadBody message ->
            "Bad Http Payload: "
                ++ message



-- HOST DECODERS


hostModelDecoder : Decoder HostModel
hostModelDecoder =
    Field.require "mapsettings" mapSettingsDecoder <|
        \mapsettings ->
            Field.require "hosts" hostListDecoder <|
                \hostlist ->
                    Decode.succeed
                        { mapSettings = mapsettings
                        , hostList = hostlist
                        }


mapSettingsDecoder : Decoder MapSettings
mapSettingsDecoder =
    Field.require "heigth" Decode.int <|
        \height ->
            Field.require "width" Decode.int <|
                \width ->
                    Field.require "active-size" Decode.int <|
                        \activeIconSize ->
                            Field.require "empty-size" Decode.int <|
                                \emptyIconSize ->
                                    Decode.succeed
                                        { height = height
                                        , width = width
                                        , activeIconSize = activeIconSize
                                        , emptyIconSize = emptyIconSize
                                        }


hostListDecoder : Decoder (List Host)
hostListDecoder =
    Decode.list hostDecoder


hostDecoder : Decoder Host
hostDecoder =
    Field.require "hostname" Decode.string <|
        \hostname ->
            Field.require "left" Decode.int <|
                \left ->
                    Field.require "top" Decode.int <|
                        \top ->
                            Decode.succeed
                                { id = hostname
                                , position = ( left, top )
                                , popState = Popover.initialState
                                }

defaultImageJson : ImageJson
defaultImageJson =
        { link = image "https://cdn.intra.42.fr/users/78999b974389f4c1370718e6c4eb0512/3b3.jpg"
        , versions =
            { large = image "https://cdn.intra.42.fr/users/6d3ac322ccab95159955311616ee167b/large_3b3.jpg"
            , micro = image "https://cdn.intra.42.fr/users/067c131574dc60e884f2dfd51943f805/micro_3b3.jpg"
            , small = image "https://cdn.intra.42.fr/users/c6ccbf99169c9599a385a6aea2e3b307/small_3b3.jpg"
            , medium = image "https://cdn.intra.42.fr/users/c3df498b1ae3803a1800eee23a3cee7a/medium_3b3.jpg"
            }
        }


-- SESSION DECODERS
compareSessionUsername : String -> Session -> Bool
compareSessionUsername username session =
    session.username == username

compareUserImageUsername : String -> UserImage -> Bool
compareUserImageUsername username userimage =
    userimage.username == username

getInitialImage : String -> (List Session) -> (List UserImage)-> Image
getInitialImage username sessionlist userimagelist =
    case List.head (List.filter (compareSessionUsername username) sessionlist) of
        Just item ->
            item.imageSrc
        Nothing ->
            case List.head (List.filter (compareUserImageUsername username) userimagelist) of
                Just item ->
                    item.image.versions.medium
                Nothing ->
                    defaultImageJson.versions.medium


sessionListDecoder : (List Session) -> (List UserImage) -> Decoder (List Session)
sessionListDecoder sessionlist userimagelist =
    Decode.list (sessionDecoder sessionlist userimagelist)


sessionDecoder : (List Session) -> (List UserImage) -> Decoder Session
sessionDecoder sessionlist userimagelist=
    Field.require "hostname" Decode.string <|
        \host ->
            Field.require "sessionType" Decode.string <|
                \sessionType ->
                    Field.attempt "login" Decode.string <|
                        \maybeUsername ->
                            case maybeUsername of
                                Just username ->
                                    Decode.succeed
                                        { username = username
                                        , host = host
                                        , imageSrc = (getInitialImage username sessionlist userimagelist)
                                        , alive = True
                                        , sessionType = sessionType
                                        }
                                Nothing ->
                                    Decode.succeed
                                        { username = ""
                                        , host = host
                                        , imageSrc = defaultImageJson.versions.medium
                                        , alive = False
                                        , sessionType = sessionType
                                        }

imageRequestListDecoder : Decoder (List UserImage)
imageRequestListDecoder =
    Decode.list imageRequestDecoder


imageRequestDecoder : Decoder UserImage
imageRequestDecoder =
    Field.require "id" Decode.int <|
        \id ->
        Field.require "login" Decode.string <|
            \username ->
                Field.require "image" imageJsonDecoder <|
                    \image ->
                        Decode.succeed
                            { id = id
                            , username = username
                            , image = image
                            }


imageJsonDecoder : Decoder ImageJson
imageJsonDecoder =
    Field.attempt "link" Decode.string <|
        \mlink ->
            case mlink of
                Just link ->
                    Field.attempt "versions" imageVersionsDecoder <|
                        \mversions ->
                            case mversions of
                                Just versions ->
                                    Decode.succeed
                                        { link = image link
                                        , versions = versions
                                        }
                                Nothing ->
                                    Decode.succeed defaultImageJson
                Nothing ->
                    Decode.succeed defaultImageJson

imageVersionsDecoder : Decoder ImageVersions
imageVersionsDecoder =
    Field.require "large" Decode.string <|
        \large ->
            Field.require "micro" Decode.string <|
                \micro ->
                    Field.require "small" Decode.string <|
                        \small ->
                            Field.require "medium" Decode.string <|
                                \medium ->
                                    Decode.succeed
                                        { micro = image micro
                                        , small = image small
                                        , medium = image medium
                                        , large = image large
                                        }
