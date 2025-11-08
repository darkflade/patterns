package ws

import (
	"encoding/json"
	"net/http"
	"server/common"
	"server/database"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func HandleWS(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("username")

	logger.Tracef("%s try to connect", username)

	if username == "" {
		logger.Warn("No username provided")
		return
	}

	db := database.GetDB()

	role, err := database.CreateUser(db, username)
	if err != nil {
		logger.Error("Failed to create user")
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logger.Errorf("Upgrade failed: %v", err)
		return
	}

	manager := GetManager()

	client := &Client{
		Username: username,
		Role:     role,
		manager:  manager,
		conn:     conn,
		send:     make(chan []byte, 256),
	}

	client.manager.register <- client

	go client.writePump()
	go client.readPump()

}

func HandleChat(client *Client, payload json.RawMessage) {
	var clientPayload common.ClientChatPayload
	err := json.Unmarshal(payload, &clientPayload)
	if err != nil {
		logger.Errorf("Error unmarshalling payload: %v", err)
		return
	}

	serverPayload := common.ServerChatPayload{
		Sender: client.Username,
		Role:   client.Role,
		Text:   clientPayload.Text,
	}

	serverPayloadBytes, err := json.Marshal(serverPayload)
	if err != nil {
		logger.Errorf("Error marshalling serverPayload: %v", err)
		return
	}

	broadcastMessage := common.Message{
		Type:    common.MessageTypeChat,
		Payload: serverPayloadBytes,
	}

	broadcastMessageBytes, err := json.Marshal(broadcastMessage)
	if err != nil {
		logger.Errorf("Error marshalling broadcast message: %v", err)
		return
	}

	client.manager.broadcast <- broadcastMessageBytes

}
