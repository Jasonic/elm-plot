module Plot
    exposing
        ( plot
        , plotInteractive
        , xAxis
        , yAxis
        , verticalGrid
        , horizontalGrid
        , hint
        , area
        , line
        , bars
        , scatter
        , custom
        , classes
        , margin
        , padding
        , size
        , style
        , domainLowest
        , domainHighest
        , rangeLowest
        , rangeHighest
        , Element
        , initialState
        , update
        , Interaction(..)
        , State
        , getHoveredValue
        )

{-|
 This library aims to allow you to visualize a variety of graphs in
 an intuitive manner without compromising flexibility regarding configuration.
 It is inspired by the elm-html api, using the `element attrs children` pattern.

 This is still in beta! The api might and probably will change!

 Just FYI, [`Svg msg`](http://package.elm-lang.org/packages/elm-lang/svg/2.0.0/Svg#Svg)
 is an alias to `VirtualDom.Node msg` and so is [`Html msg`](http://package.elm-lang.org/packages/elm-lang/html/2.0.0/Html#Html).
 This means that the types are basically interchangable and you can use the same methods on them.

# Definitions
@docs  Element

# Elements
@docs plot, plotInteractive, xAxis, yAxis, hint, verticalGrid, horizontalGrid, custom

## Series
@docs scatter, line, area, bars

# Styling and sizes
@docs classes, margin, padding, size, style, domainLowest, domainHighest, rangeLowest, rangeHighest

# State
For an example of the update flow see [this example](https://github.com/terezka/elm-plot/blob/master/examples/Interactive.elm).

@docs State, initialState, update, Interaction, getHoveredValue


-}

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Svg exposing (Svg)
import Svg.Attributes
import Svg.Lazy
import Json.Decode as Json
import DOM
import Plot.Bars as Bars
import Plot.Hint as Hint
import Plot.Types exposing (..)
import Internal.Grid as GridInternal
import Internal.Axis as AxisInternal
import Internal.Bars as BarsInternal
import Internal.Area as AreaInternal
import Internal.Scatter as ScatterInternal
import Internal.Line as LineInternal
import Internal.Hint as HintInternal
import Internal.Stuff exposing (..)
import Internal.Types exposing (..)
import Internal.Draw exposing (..)
import Internal.Scale exposing (..)
import Plot.Attributes as Attributes exposing (..)


{-| Represents a child element of the plot.
-}
type Element msg
    = Line (LineStyle msg) (List Point)
    | Area (AreaStyle msg) (List Point)
    | Bars (Bars msg) (List (BarsStyle msg)) (List Bars.Data)
    | Scatter (Scatter msg) (List Point)
    | Hint (HintInternal.Config msg) (Maybe Point)
    | Axis (Axis msg)
    | Grid (Grid msg)
    | CustomElement ((Point -> Point) -> Svg.Svg msg)


type alias Plot =
    { size : Oriented Float
    , padding : ( Float, Float )
    , margin : ( Float, Float, Float, Float )
    , classes : List String
    , style : Style
    , domain : EdgesAny (Float -> Float)
    , range : EdgesAny (Float -> Float)
    , id : String
    }


defaultConfig : Plot
defaultConfig =
    { size = Oriented 800 500
    , padding = ( 0, 0 )
    , margin = ( 0, 0, 0, 0 )
    , classes = []
    , style = []
    , domain = EdgesAny (identity) (identity)
    , range = EdgesAny (identity) (identity)
    , id = "elm-plot"
    }


{-| Adds padding to your plot, meaning extra space below
 and above the lowest and highest point in your plot.
 The unit is pixels and the format is `( bottom, top )`.

 Default: `( 0, 0 )`
-}
padding : ( Int, Int ) -> Attribute Plot
padding ( bottom, top ) config =
    { config | padding = ( toFloat bottom, toFloat top ) }


{-| Specify the size of your plot in pixels and in the format
 of `( width, height )`.

 Default: `( 800, 500 )`
-}
size : ( Int, Int ) -> Attribute Plot
size ( width, height ) config =
    { config | size = Oriented (toFloat width) (toFloat height) }


{-| Specify margin around the plot. Useful when your ticks are outside the
 plot and you would like to add space to see them! Values are in pixels and
the format is `( top, right, bottom, left )`.

 Default: `( 0, 0, 0, 0 )`
-}
margin : ( Int, Int, Int, Int ) -> Attribute Plot
margin ( t, r, b, l ) config =
    { config | margin = ( toFloat t, toFloat r, toFloat b, toFloat l ) }


{-| Adds styles to the svg element.
-}
style : Style -> Attribute Plot
style style config =
    { config | style = defaultConfig.style ++ style ++ [ ( "padding", "0" ) ] }


{-| Adds classes to the svg element.
-}
classes : List String -> Attribute Plot
classes classes config =
    { config | classes = classes }


{-| Adds an id to the svg element.
-}
id : String -> Attribute Plot
id id config =
    { config | id = id }


{-| Alter the domain's lower boundary. The function provided will
 be passed the lowest y-value present in any of your series and the result will
 be the lower boundary of your series. So if you would like
 the lowest boundary to simply be the edge of your series, then set
 this attribute to the function `identity`.
 If you want it to always be -5, then set this attribute to the function `always -5`.

 The default is `identity`.

 **Note:** If you are using `padding` as well, the extra padding will still be
 added outside the domain.
-}
domainLowest : (Float -> Float) -> Attribute Plot
domainLowest toLowest ({ domain } as config) =
    { config | domain = { domain | lower = toLowest } }


{-| Alter the domain's upper boundary. The function provided will
 be passed the lowest y-value present in any of your series and the result will
 be the upper boundary of your series. So if you would like
 the lowest boundary to  always be 10, then set this attribute to the function `always 10`.

 The default is `identity`.

 **Note:** If you are using `padding` as well, the extra padding will still be
 added outside the domain.
-}
domainHighest : (Float -> Float) -> Attribute Plot
domainHighest toHighest ({ domain } as config) =
    { config | domain = { domain | upper = toHighest } }


{-| Provide a function to determine the lower boundary of range.
 See `domainLowest` and imagine we're talking about the x-axis.
-}
rangeLowest : (Float -> Float) -> Attribute Plot
rangeLowest toLowest ({ range } as config) =
    { config | range = { range | lower = toLowest } }


{-| Provide a function to determine the upper boundary of range.
 See `domainHighest` and imagine we're talking about the x-axis.
-}
rangeHighest : (Float -> Float) -> Attribute Plot
rangeHighest toHighest ({ range } as config) =
    { config | range = { range | upper = toHighest } }


{-| -}
xAxis : List (Attribute (Axis msg)) -> Element msg
xAxis attrs =
    Axis (List.foldl (<|) defaultAxisConfig attrs)


{-| -}
yAxis : List (Attribute (Axis msg)) -> Element msg
yAxis attrs =
    Axis (List.foldl (<|) { defaultAxisConfig | orientation = Y } attrs)


{-| -}
horizontalGrid : List (Attribute (Grid msg)) -> Element msg
horizontalGrid attrs =
    Grid (List.foldr (<|) defaultGridConfig attrs)


{-| -}
verticalGrid : List (Attribute (Grid msg)) -> Element msg
verticalGrid attrs =
    Grid (List.foldr (<|) { defaultGridConfig | orientation = Y } attrs)


{-| -}
area : List (Attribute (AreaStyle msg)) -> List Point -> Element msg
area attrs points =
    Area (List.foldr (<|) defaultAreaStyle attrs) points


{-| -}
line : List (Attribute (LineStyle msg)) -> List Point -> Element msg
line attrs points =
    Line (List.foldr (<|) defaultLineStyle attrs) points


{-| -}
scatter : List (Attribute (Scatter msg)) -> List Point -> Element msg
scatter attrs =
    Scatter (List.foldr (<|) defaultScatterConfig attrs)


{-| This wraps all your bar series.
-}
bars : List (Attribute (Bars msg)) -> List (List (Attribute (BarsStyle msg))) -> List Bars.Data -> Element msg
bars attrs styleAttrsList groups =
    Bars
        (List.foldr (<|) defaultBarsConfig attrs)
        (List.map (List.foldr (<|) defaultBarsStyle) styleAttrsList)
        groups


{-| Adds a hint to your plot. See [this example](https://github.com/terezka/elm-plot/blob/master/examples/Interactive.elm)

 Remember to use `plotInteractive` for the events to be processed!.
-}
hint : List (Hint.Attribute msg) -> Maybe Point -> Element msg
hint attrs position =
    Hint (List.foldr (<|) HintInternal.defaultConfig attrs) position


{-| This element is passed a function which can translate your values into
 svg coordinates. This way you can build your own serie types. Although
 if you feel like you're missing something let me know!
-}
custom : ((Point -> Point) -> Svg.Svg msg) -> Element msg
custom view =
    CustomElement view


{-| This is the function processing your entire plot configuration.
 Pass your attributes and elements to this function and
 a SVG plot will be returned!
-}
plot : List (Attribute Plot) -> List (Element msg) -> Svg msg
plot attrs =
    Svg.Lazy.lazy2 parsePlot (toPlotConfig attrs)


{-| So this is like `plot`, except the message to is `Interaction msg`. It's a message wrapping
 your message, so you can use the build in interactions (like the hint!) in the plot as well as adding your own.
 See [this example](https://github.com/terezka/elm-plot/blob/master/examples/Interactive.elm).
-}
plotInteractive : List (Attribute Plot) -> List (Element (Interaction msg)) -> Svg (Interaction msg)
plotInteractive attrs =
    Svg.Lazy.lazy2 parsePlotInteractive (toPlotConfig attrs)


toPlotConfig : List (Attribute Plot) -> Plot
toPlotConfig =
    List.foldl (<|) defaultConfig



-- MODEL


{-| -}
type State
    = State StateInner


type alias StateInner =
    { position : Maybe ( Float, Float ) }


{-| -}
initialState : State
initialState =
    State { position = Nothing }



-- UPDATE


{-| -}
type Interaction msg
    = Internal Msg
    | Custom msg


type Msg
    = Hovering ( Float, Float )
    | ResetPosition


{-| -}
update : Msg -> State -> State
update msg (State state) =
    case msg of
        Hovering position ->
            if shouldPositionUpdate state position then
                State { state | position = Just position }
            else
                State state

        ResetPosition ->
            State { position = Nothing }


{-| Get the hovered position from state.
-}
getHoveredValue : State -> Maybe Point
getHoveredValue (State { position }) =
    position


shouldPositionUpdate : StateInner -> ( Float, Float ) -> Bool
shouldPositionUpdate { position } ( left, top ) =
    case position of
        Nothing ->
            True

        Just ( leftOld, topOld ) ->
            topOld /= top || leftOld /= left


getRelativePosition : Meta -> ( Float, Float ) -> ( Float, Float ) -> ( Maybe Float, Float )
getRelativePosition { fromSvgCoords, toNearestX } ( mouseX, mouseY ) ( left, top ) =
    let
        ( x, y ) =
            fromSvgCoords ( mouseX - left, mouseY - top )
    in
        ( toNearestX x, y )


handleMouseOver : Meta -> Json.Decoder (Interaction msg)
handleMouseOver meta =
    Json.map3
        (toMouseOverMsg meta)
        (Json.field "clientX" Json.float)
        (Json.field "clientY" Json.float)
        (DOM.target getPlotPosition)


toMouseOverMsg : Meta -> Float -> Float -> ( Float, Float ) -> Interaction msg
toMouseOverMsg meta mouseX mouseY position =
    let
        relativePosition =
            getRelativePosition meta ( mouseX, mouseY ) position
    in
        case Tuple.first relativePosition of
            Just x ->
                Internal (Hovering ( x, Tuple.second relativePosition ))

            Nothing ->
                Internal ResetPosition


getPlotPosition : Json.Decoder ( Float, Float )
getPlotPosition =
    Json.oneOf
        [ getPosition
        , Json.lazy (\_ -> getParentPosition)
        ]


getPosition : Json.Decoder ( Float, Float )
getPosition =
    Json.map (\{ left, top } -> ( left, top )) DOM.boundingClientRect


getParentPosition : Json.Decoder ( Float, Float )
getParentPosition =
    DOM.parentElement getPlotPosition



-- VIEW


parsePlot : Plot -> List (Element msg) -> Svg msg
parsePlot config elements =
    let
        meta =
            calculateMeta config elements
    in
        viewPlot config meta (viewElements meta elements)


parsePlotInteractive : Plot -> List (Element (Interaction msg)) -> Svg (Interaction msg)
parsePlotInteractive config elements =
    let
        meta =
            calculateMeta config elements
    in
        viewPlotInteractive config meta (viewElements meta elements)


viewPlotInteractive : Plot -> Meta -> ( List (Svg (Interaction msg)), List (Html (Interaction msg)) ) -> Html (Interaction msg)
viewPlotInteractive config meta ( svgViews, htmlViews ) =
    Html.div
        (plotAttributes config ++ plotAttributesInteraction meta)
        (viewSvg meta config svgViews :: htmlViews)


viewPlot : Plot -> Meta -> ( List (Svg msg), List (Html msg) ) -> Svg msg
viewPlot config meta ( svgViews, htmlViews ) =
    Html.div
        (plotAttributes config)
        (viewSvg meta config svgViews :: htmlViews)


plotAttributes : Plot -> List (Html.Attribute msg)
plotAttributes { size, style, id } =
    [ Html.Attributes.class "elm-plot"
    , Html.Attributes.id id
    , Html.Attributes.style <| sizeStyle size ++ style
    ]


plotAttributesInteraction : Meta -> List (Html.Attribute (Interaction msg))
plotAttributesInteraction meta =
    [ Html.Events.on "mousemove" (handleMouseOver meta)
    , Html.Events.onMouseLeave (Internal ResetPosition)
    ]


viewSvg : Meta -> Plot -> List (Svg msg) -> Svg msg
viewSvg meta config views =
    Svg.svg
        [ Svg.Attributes.height (toString config.size.y)
        , Svg.Attributes.width (toString config.size.x)
        , Svg.Attributes.class "elm-plot__inner"
        ]
        (scaleDefs meta :: views)


scaleDefs : Meta -> Svg.Svg msg
scaleDefs meta =
    Svg.defs []
        [ Svg.clipPath [ Svg.Attributes.id (toClipPathId meta) ]
            [ Svg.rect
                [ Svg.Attributes.x (toString meta.scale.x.offset.lower)
                , Svg.Attributes.y (toString meta.scale.y.offset.lower)
                , Svg.Attributes.width (toString meta.scale.x.length)
                , Svg.Attributes.height (toString meta.scale.y.length)
                ]
                []
            ]
        ]


sizeStyle : Oriented Float -> Style
sizeStyle { x, y } =
    [ ( "height", toPixels y ), ( "width", toPixels x ) ]


viewElements : Meta -> List (Element msg) -> ( List (Svg msg), List (Html msg) )
viewElements meta elements =
    List.foldr (viewElement meta) ( [], [] ) elements


viewElement : Meta -> Element msg -> ( List (Svg msg), List (Html msg) ) -> ( List (Svg msg), List (Html msg) )
viewElement meta element ( svgViews, htmlViews ) =
    case element of
        Line config points ->
            ( (LineInternal.view meta config points) :: svgViews, htmlViews )

        Area config points ->
            ( (AreaInternal.view meta config points) :: svgViews, htmlViews )

        Scatter config points ->
            ( (ScatterInternal.view meta config points) :: svgViews, htmlViews )

        Bars config styleConfigs groups ->
            ( (BarsInternal.view meta config styleConfigs groups) :: svgViews, htmlViews )

        Axis ({ orientation } as config) ->
            ( (AxisInternal.view (getFlippedMeta orientation meta) config) :: svgViews, htmlViews )

        Grid ({ orientation } as config) ->
            ( (GridInternal.view (getFlippedMeta orientation meta) config) :: svgViews, htmlViews )

        CustomElement view ->
            ( (view meta.toSvgCoords :: svgViews), htmlViews )

        Hint config position ->
            case position of
                Just point ->
                    ( svgViews, (HintInternal.view meta config point) :: htmlViews )

                Nothing ->
                    ( svgViews, htmlViews )



-- CALCULATIONS OF META


calculateMeta : Plot -> List (Element msg) -> Meta
calculateMeta ({ size, padding, margin, range, domain, id } as config) elements =
    let
        values =
            toValuesOriented elements

        internalBounds =
            List.foldl foldInternalBounds (Oriented Nothing Nothing) elements

        axisConfigs =
            toAxisConfigsOriented elements

        ( top, right, bottom, left ) =
            margin

        xScale =
            getScale size.x range internalBounds.x (Edges left right) ( 0, 0 ) values.x

        yScale =
            getScale size.y domain internalBounds.y (Edges top bottom) padding values.y

        xTicks =
            getLastGetTickValues axisConfigs.x xScale

        yTicks =
            getLastGetTickValues axisConfigs.y yScale
    in
        { scale = Oriented xScale yScale
        , toSvgCoords = toSvgCoordsX xScale yScale
        , oppositeToSvgCoords = toSvgCoordsY xScale yScale
        , fromSvgCoords = fromSvgCoords xScale yScale
        , ticks = xTicks
        , oppositeTicks = yTicks
        , axisCrossings = getAxisCrossings axisConfigs.x yScale
        , oppositeAxisCrossings = getAxisCrossings axisConfigs.y xScale
        , toNearestX = toNearest values.x
        , getHintInfo = getHintInfo elements
        , id = id
        }


toValuesOriented : List (Element msg) -> Oriented (List Value)
toValuesOriented elements =
    List.foldr foldPoints [] elements
        |> List.unzip
        |> (\( x, y ) -> Oriented x y)


foldPoints : Element msg -> List Point -> List Point
foldPoints element allPoints =
    case element of
        Area config points ->
            allPoints ++ points

        Line config points ->
            allPoints ++ points

        Scatter config points ->
            allPoints ++ points

        Bars config styleConfigs groups ->
            allPoints ++ (BarsInternal.toPoints config groups)

        _ ->
            allPoints


foldInternalBounds : Element msg -> Oriented (Maybe Edges) -> Oriented (Maybe Edges)
foldInternalBounds element =
    case element of
        Area config points ->
            foldInternalBoundsArea

        Bars config styleConfigs groups ->
            foldInternalBoundsBars config groups >> foldInternalBoundsArea

        _ ->
            identity


foldInternalBoundsArea : Oriented (Maybe Edges) -> Oriented (Maybe Edges)
foldInternalBoundsArea bounds =
    { bounds | y = Just (foldBounds bounds.y { lower = 0, upper = 0 }) }


foldInternalBoundsBars : Bars msg -> List Group -> Oriented (Maybe Edges) -> Oriented (Maybe Edges)
foldInternalBoundsBars config groups bounds =
    let
        allBarPoints =
            BarsInternal.toPoints config groups

        ( allBarXValues, _ ) =
            List.unzip allBarPoints

        newXBounds =
            updateInternalBounds
                bounds.x
                { lower = getLowest allBarXValues - 0.5
                , upper = getHighest allBarXValues + 0.5
                }
    in
        { bounds | x = newXBounds }


updateInternalBounds : Maybe Edges -> Edges -> Maybe Edges
updateInternalBounds old new =
    Just (foldBounds old new)


flipMeta : Meta -> Meta
flipMeta ({ scale, toSvgCoords, oppositeToSvgCoords, ticks, oppositeTicks, axisCrossings, oppositeAxisCrossings } as meta) =
    { meta
        | scale = flipOriented scale
        , toSvgCoords = oppositeToSvgCoords
        , oppositeToSvgCoords = toSvgCoords
        , axisCrossings = oppositeAxisCrossings
        , oppositeAxisCrossings = axisCrossings
        , ticks = oppositeTicks
        , oppositeTicks = ticks
    }


getFlippedMeta : Orientation -> Meta -> Meta
getFlippedMeta orientation meta =
    case orientation of
        X ->
            meta

        Y ->
            flipMeta meta


getHintInfo : List (Element msg) -> Float -> Hint.HintInfo
getHintInfo elements xValue =
    Hint.HintInfo xValue <| List.foldr (collectYValues xValue) [] elements


toAxisConfigsOriented : List (Element msg) -> Oriented (List (Axis msg))
toAxisConfigsOriented =
    List.foldr foldAxisConfigs { x = [], y = [] }


foldAxisConfigs : Element msg -> Oriented (List (Axis msg)) -> Oriented (List (Axis msg))
foldAxisConfigs element axisConfigs =
    case element of
        Axis ({ orientation } as config) ->
            foldOriented (\configs -> config :: configs) orientation axisConfigs

        _ ->
            axisConfigs


getLastGetTickValues : List (Axis msg) -> Scale -> List Value
getLastGetTickValues axisConfigs =
    List.head axisConfigs
        |> Maybe.withDefault defaultAxisConfig
        |> .tick
        |> .values
        |> AxisInternal.getValues


collectYValues : Float -> Element msg -> List (Maybe (List Value)) -> List (Maybe (List Value))
collectYValues xValue element yValues =
    case element of
        Area config points ->
            collectYValue xValue points :: yValues

        Line config points ->
            collectYValue xValue points :: yValues

        Scatter config points ->
            collectYValue xValue points :: yValues

        Bars config styleConfigs groups ->
            BarsInternal.getYValues xValue groups :: yValues

        _ ->
            yValues


collectYValue : Float -> List Point -> Maybe (List Value)
collectYValue xValue points =
    List.foldr (getYValue xValue) Nothing points


getYValue : Float -> Point -> Maybe (List Value) -> Maybe (List Value)
getYValue xValue ( x, y ) result =
    if x == xValue then
        Just [ y ]
    else
        result


getAxisCrossings : List (Axis msg) -> Scale -> List Value
getAxisCrossings axisConfigs oppositeScale =
    List.map (AxisInternal.getAxisPosition oppositeScale << .position) axisConfigs
