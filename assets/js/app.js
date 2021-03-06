import "phoenix_html"

import Elm from './main'

const elmDiv = document.querySelector('#elm-target');

if (elmDiv) {
    const websocketUrl = 'ws://' + window.location.host + '/socket/websocket'
    const main = Elm.Main.embed(elmDiv, {websocketUrl: websocketUrl});
    const requestAnimationFrame =
       window.requestAnimationFrame ||
       window.mozRequestAnimationFrame ||
       window.webkitRequestAnimationFrame ||
       window.msRequestAnimationFrame

    main.ports.fetchDomElements.subscribe(selector => {
        // For now the best solution available
        // https://stackoverflow.com/questions/38952724/how-to-coordinate-rendering-with-port-interactions-elm-0-17
        requestAnimationFrame(() => {
            main.ports.domElements.send(
                Array.from(document.querySelectorAll(selector))
            )
        })
    })
}
