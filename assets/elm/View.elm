module View exposing (..)

import Array exposing (Array)
import Date exposing (Date)
import Date.Extra.Config.Config_en_au as DateConfig
import Date.Extra.Format as DateFormat
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Encode
import Models exposing (DomElement, Model, Msg(..), Pipeline, Project, Status(..))
import Time


type alias ViewPipeline =
    { progressSeconds : Int
    , remainingSeconds : Int
    , progressPercent : Float
    , commitAuthor : String
    , commitMessage : String
    , commitCreatedAt : Date
    }


type alias ViewProject =
    { id : String
    , name : String
    , image : String
    , status : Maybe String
    , commitAuthor : String
    , commitMessage : String
    , commitCreatedAt : Date
    , pipelinesCurrentCommit : List ViewPipeline
    , pipelinesPreviousCommits : List ViewPipeline
    }


createViewPipeline : Model -> Project -> Pipeline -> ViewPipeline
createViewPipeline model project pipeline =
    let
        progressSeconds =
            Time.inSeconds model.now
                - Time.inSeconds (Date.toTime pipeline.createdAt)
                |> Basics.max 0

        progressPercent =
            case project.duration of
                0 ->
                    0

                _ ->
                    progressSeconds
                        / project.duration
                        * 100
                        |> Basics.min 100
                        |> Basics.max 0

        remainingSeconds =
            project.duration - progressSeconds |> Basics.max 0
    in
    ViewPipeline
        (round progressSeconds)
        (round remainingSeconds)
        progressPercent
        pipeline.commitAuthor
        pipeline.commitMessage
        pipeline.commitCreatedAt


projectsSelector : Model -> List ViewProject
projectsSelector model =
    List.map
        (\p ->
            ViewProject
                p.id
                p.name
                p.image
                p.status
                p.commitAuthor
                p.commitMessage
                p.commitCreatedAt
                (List.map
                    (\pipeline ->
                        createViewPipeline model p pipeline
                    )
                 <|
                    List.filter
                        (\pl -> pl.commitSha == p.commitSha)
                        p.pipelines
                )
                (List.map
                    (\pipeline ->
                        createViewPipeline model p pipeline
                    )
                 <|
                    List.filter
                        (\pl -> pl.commitSha /= p.commitSha)
                        p.pipelines
                )
        )
        model.projects


view : Model -> Html Msg
view model =
    div []
        [ viewProjects model.projectDomElements (projectsSelector model)
        , viewStatusPanel model
        ]


viewStatusPanel : Model -> Html Msg
viewStatusPanel model =
    div
        [ id "statusPanel"
        , classList [ ( "error", isStatusError model.status ) ]
        ]
        [ text (statusText model.status)
        ]


isStatusError : Status -> Bool
isStatusError status =
    case status of
        Error _ ->
            True

        _ ->
            False


statusText : Status -> String
statusText status =
    case status of
        Updated date ->
            "Updated " ++ formatDate date

        Error error ->
            "Error: " ++ error


listToDict : (a -> comparable) -> List a -> Dict comparable a
listToDict f =
    List.map (\v -> ( f v, v ))
        >> Dict.fromList


projectHeights : List DomElement -> List ViewProject -> List Float
projectHeights elements =
    let
        elemDict =
            listToDict .id elements
    in
    List.map
        (\project ->
            elemDict
                |> Dict.get project.id
                |> Maybe.map .offsetHeight
                |> Maybe.withDefault 1
        )


viewProjects : List DomElement -> List ViewProject -> Html Msg
viewProjects domElements projects =
    projects
        |> List.map viewProject
        |> columnize 2 (projectHeights domElements projects)
        |> div [ id "container" ]


columnize : Int -> List Float -> List (Html Msg) -> List (Html Msg)
columnize count heights nodes =
    List.map2 (\height node -> ( height, node )) heights nodes
        |> List.foldl columnizeStep (Array.repeat count ( 0, [] ))
        |> Array.toList
        |> List.map
            (\( _, column ) ->
                div [ class "column" ] column
            )


columnizeStep : ( Float, a ) -> Array ( Float, List a ) -> Array ( Float, List a )
columnizeStep ( height, node ) columns =
    let
        defaultColumn =
            columns
                |> Array.get 0
                |> Maybe.withDefault ( 0, [] )

        ( theIndex, ( theHeight, theColumn ) ) =
            List.foldl
                (\new current ->
                    let
                        ( _, ( newHeight, newColumn ) ) =
                            new

                        ( _, ( currentHeight, currentColumn ) ) =
                            current

                        overlap =
                            newHeight - currentHeight + height

                        maxOverlap =
                            height / 2

                        len =
                            List.length
                    in
                    if overlap < maxOverlap then
                        new
                    else if newHeight < currentHeight && len newColumn < len currentColumn then
                        new
                    else
                        current
                )
                ( 0, defaultColumn )
                (Array.toIndexedList columns)
    in
    Array.set theIndex ( theHeight + height, theColumn ++ [ node ] ) columns


trimText : Int -> String -> String
trimText length text =
    text
        |> String.left length
        |> (\newText ->
                if newText == text then
                    newText
                else
                    newText ++ "..."
           )


viewProject : ViewProject -> Html Msg
viewProject project =
    [ img [ class "project-image", src project.image ] []
    , div [ class "project-content" ]
        [ div [ class "project-header" ] <|
            [ h2 [] [ text project.name ]
            ]
                ++ viewStatus project.status
        , p [ class "project-commit" ]
            [ div [] [ text (trimText 210 project.commitMessage) ]
            , div [ class "info" ]
                [ text
                    (String.join " "
                        [ "by"
                        , project.commitAuthor
                        , formatDate project.commitCreatedAt
                        ]
                    )
                ]
            ]
        , div [] <| List.map viewPipelineCurrentCommit project.pipelinesCurrentCommit
        , div [] <| List.map viewPipelinePreviousCommits project.pipelinesPreviousCommits
        ]
    ]
        |> div [ class "project" ]
        |> List.singleton
        |> div
            [ class "project-wrap"
            , property "projectId" (Json.Encode.string project.id)
            ]


viewStatus : Maybe String -> List (Html Msg)
viewStatus status =
    case status of
        Just s ->
            [ span [ class ("badge " ++ s) ] [ text s ]
            ]

        Nothing ->
            []


viewPipelineCurrentCommit : ViewPipeline -> Html Msg
viewPipelineCurrentCommit pipeline =
    div []
        [ progress [ Html.Attributes.max "100", value (toString pipeline.progressPercent) ] []
        , div [ class "row" ]
            [ span [ class "col4" ] [ text (formatTime pipeline.progressSeconds) ]
            , span [ class "col4 center" ] [ text (toString (round pipeline.progressPercent) ++ "%") ]
            , span [ class "col4 right" ] [ text (formatTime pipeline.remainingSeconds) ]
            ]
        ]


viewPipelinePreviousCommits : ViewPipeline -> Html Msg
viewPipelinePreviousCommits pipeline =
    div [ class "pipeline-small" ]
        [ progress [ Html.Attributes.max "100", value (toString pipeline.progressPercent) ] []
        , p [ class "project-commit" ]
            [ div [] [ text (trimText 80 pipeline.commitMessage) ]
            , div [ class "info" ]
                [ text
                    (String.join " "
                        [ "by"
                        , pipeline.commitAuthor
                        , formatDate pipeline.commitCreatedAt
                        ]
                    )
                ]
            ]
        ]


formatDate : Date -> String
formatDate =
    DateFormat.format DateConfig.config "on %d/%m/%Y at %H:%M:%S"


{-| Format 72 seconds as "1:12"
-}
formatTime : Int -> String
formatTime seconds =
    let
        m =
            seconds // 60

        s =
            seconds - m * 60
    in
    toString m ++ ":" ++ (toString s |> String.padLeft 2 '0')
