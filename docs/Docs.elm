port module Docs exposing (..)

import Html exposing (Html, div, text, h1, img, a, br, span, code, pre, p)
import Html.Attributes exposing (style, src, href, class)
import Html.Events exposing (onClick)
import Svg
import Svg.Attributes
import Random
import Time exposing (Time, minute)

import Plot exposing (..)
import AreaChart exposing (..)
import MultiAreaChart exposing (..)
import GridChart exposing (..)
import MultiLineChart exposing (..)
import CustomTickChart exposing (..)
import ComposedChart exposing (..)


-- MODEL


type alias Model =
    { openSnippet : Maybe String
    , data : List (Float, Float)
    }


init : ( Model, Cmd Msg )
init =
    (!) initModel [ fetchNewData, highlight "none" ]


initModel : Model
initModel =
    { openSnippet = Nothing
    , data = []
    }



-- UPDATE


type Msg
    = Toggle (Maybe String)
    | NewData (List Float)
    | Tick Time


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Toggle sectionId ->
            ( { model | openSnippet = sectionId }, Cmd.none )

        Tick _ ->
            ( model, fetchNewData )

        NewData data ->
            ( { model | data = List.indexedMap (\i v -> (toFloat i, v)) data }, Cmd.none )


fetchNewData : Cmd Msg
fetchNewData =
    Random.generate NewData (Random.list 10 (Random.float 0 100))


-- VIEW


viewTitle : Model -> String -> String -> String -> Html Msg
viewTitle { openSnippet } title name codeString =
    let
        isOpen =
            case openSnippet of
                Just id ->
                    id == title

                Nothing ->
                    False

        codeStyle =
            if isOpen then
                ( "display", "block" )
            else
                ( "display", "none" )

        onClickMsg =
            if isOpen then
                Toggle Nothing
            else
                Toggle (Just title)
    in
        div [ style [ ( "margin", "100px auto 10px" ) ] ]
            [ div [] [ text title ]
            , p
                [ style
                    [ ( "color", "#9ea0a2" )
                    , ( "font-size", "12px" )
                    , ( "cursor", "pointer" )
                    ]
                , onClick onClickMsg
                ]
                [ text "View code snippet" ]
            , div
                [ style
                    (codeStyle
                        :: [ ( "text-align", "right" )
                           , ( "margin", "30px auto" )
                           , ( "width", "600px" )
                           , ( "position", "relative" )
                           ]
                    )
                ]
                [ Html.code
                    [ class "elm"
                    , style [ ( "text-align", "left" ) ]
                    ]
                    [ pre [] [ text codeString ] ]
                , a
                    [ style
                        [ ( "font-size", "12px" )
                        , ( "color", "#9ea0a2" )
                        , ( "position", "absolute" )
                        , ( "top", "0" )
                        , ( "right", "0" )
                        , ( "margin", "15px 20px" )
                        ]
                    , href (toUrl name)
                    ]
                    [ text "See full code" ]
                ]
            ]


view : Model -> Html Msg
view model =
    div
        [ style
            [ ( "width", "800px" )
            , ( "margin", "80px auto" )
            , ( "font-family", "sans-serif" )
            , ( "color", "#7F7F7F" )
            , ( "font-weight", "200" )
            , ( "text-align", "center" )
            ]
        ]
        [ img [ src "logo.png", style [ ( "width", "100px" ), ( "height", "100px" ) ] ] []
        , h1 [ style [ ( "font-weight", "200" ) ] ] [ text "Elm Plot" ]
        , div
            [ style [ ( "margin", "40px auto 100px" ) ] ]
            [ text "Find it on "
            , a
                [ href "https://github.com/terezka/elm-plot"
                , style [ ( "color", "#84868a" ) ]
                ]
                [ text "Github" ]
            ]
        , viewTitle model "Simple Area Chart" "AreaChart" AreaChart.code
        , AreaChart.chart model.data
        , viewTitle model "Multi Area Chart" "MultiAreaChart" MultiAreaChart.code
        , MultiAreaChart.chart
        , viewTitle model "Line Chart" "MultiLineChart" MultiLineChart.code
        , MultiLineChart.chart
        , viewTitle model "Grid" "GridChart" GridChart.code
        , GridChart.chart
        , viewTitle model "Custom ticks and labels" "CustomTickChart" CustomTickChart.code
        , CustomTickChart.chart
        , viewTitle model "Composable" "ComposedChart" ComposedChart.code
        , ComposedChart.chart
        , div
            [ style [ ( "margin", "100px auto 30px" ), ( "font-size", "14px" ) ] ]
            [ text "Made by "
            , a
                [ href "https://twitter.com/terexka"
                , style [ ( "color", "#84868a" ) ]
                ]
                [ text "@terexka" ]
            ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Time.every minute Tick


main =
    Html.program
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- Ports


port highlight : String -> Cmd msg



-- Helpers


toUrl : String -> String
toUrl end =
    "https://github.com/terezka/elm-plot/blob/master/docs/" ++ end ++ ".elm"
