package ws

import (
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func HandleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}

	manager := GetManager()

	client := &Client{
		manager: manager,
		conn:    conn,
		send:    make(chan []byte, 256),
	}

	client.manager.register <- client

	go client.writePump()
	go client.readPump()

}
