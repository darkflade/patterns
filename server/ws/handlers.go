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

func GetWSClients(wsWriter common.WebSocketWriter) {
	manager := GetManager()

	manager.mu.RLock()
	defer manager.mu.RUnlock()

	activeClientsInfo := make([]common.ActiveClients, 0, len(manager.clients))

	for client := range manager.clients {
		activeClientsInfo = append(activeClientsInfo, common.ActiveClients{
			Username: client.Username,
			Role:     client.Role,
		})
	}

	activeClientsInfoBytes, err := json.Marshal(activeClientsInfo)
	if err != nil {
		logger.Errorf("Error marshalling activeClientsInfo: %v", err)
		return
	}

	clientsToSend := common.Message{
		Type:    common.MessageTypeActiveClientsWSResponse,
		Payload: activeClientsInfoBytes,
	}

	err = wsWriter.WriteJSON(clientsToSend)
	if err != nil {
		logger.Errorf("Failed to send active clients: %v", err)
	}
}

func HandlePromoteUser(client *Client, payload json.RawMessage) {
	if client.Role != "admin" {
		sendSystemError(client, "У вас нет прав для выполнения этой команды.")
		return
	}

	var promotePayload common.PromoteUserPayload
	if err := json.Unmarshal(payload, &promotePayload); err != nil {
		sendSystemError(client, "Некорректные данные для команды promote_user.")
		return
	}

	if promotePayload.NewRole != "admin" && promotePayload.NewRole != "moderator" {
		sendSystemError(client, "Можно назначить только роль 'admin' или 'moderator'.")
		return
	}

	wsManager := GetManager()

	wsManager.mu.Lock()
	defer wsManager.mu.Unlock()

	var targetClient *Client
	for c := range wsManager.clients {
		if c.Username == promotePayload.Username {
			targetClient = c
			break
		}
	}

	if targetClient == nil {
		sendSystemError(client, "Пользователь с таким именем не найден.")
		return
	}

	targetClient.Role = promotePayload.NewRole
	logger.Infof("Админ '%s' повысил '%s' до роли '%s'", client.Username, targetClient.Username, targetClient.Role)

	db := database.GetDB()
	database.UpdateUser(db, targetClient.Username, targetClient.Role)

	go sendUpdatedUserListToAll()
}

func sendSystemError(client *Client, errorMessage string) {
	errorPayload := map[string]string{"error": errorMessage}
	payloadBytes, err := json.Marshal(errorPayload)
	if err != nil {
		logger.Errorf("Error marshalling errorMessage: %v", err)
		return
	}

	errorMessageToSend := common.Message{
		Type:    common.MessageTypeSystemError,
		Payload: payloadBytes,
	}

	errorMessageToSendBytes, err := json.Marshal(errorMessageToSend)
	if err != nil {
		logger.Errorf("Error marshalling errorMessage: %v", err)
		return
	}

	client.send <- errorMessageToSendBytes
}

func sendUpdatedUserListToAll() {
	manager := GetManager()

	manager.mu.RLock()
	defer manager.mu.RUnlock()

	activeClientsInfo := make([]common.ActiveClients, 0, len(manager.clients))

	for client := range manager.clients {
		activeClientsInfo = append(activeClientsInfo, common.ActiveClients{
			Username: client.Username,
			Role:     client.Role,
		})
	}

	activeClientsInfoBytes, err := json.Marshal(activeClientsInfo)
	if err != nil {
		logger.Errorf("Error marshalling activeClientsInfo: %v", err)
		return
	}

	clientsToSend := common.Message{
		Type:    common.MessageTypeActiveClientsWSResponse,
		Payload: activeClientsInfoBytes,
	}

	clientsToSendBytes, err := json.Marshal(clientsToSend)
	if err != nil {
		logger.Errorf("Error marshalling clientsToSend: %v", err)
		return
	}

	manager.broadcast <- clientsToSendBytes
}

func HandleJoinUserResponse(username string, role string) {
	wsManager := GetManager()

	joinPayload := map[string]string{
		"username": username,
		"role":     role,
	}

	joinPayloadBytes, err := json.Marshal(joinPayload)
	if err != nil {
		logger.Errorf("Error marshalling joinPayload: %v", err)
	}

	joinUserNotificationMessage := common.Message{
		Type:    common.MessageTypeUserJoinResponse,
		Payload: joinPayloadBytes,
	}

	joinUserNotificationMessageBytes, err := json.Marshal(joinUserNotificationMessage)
	if err != nil {
		logger.Errorf("Error marshalling joinUserNotificationMessage: %v", err)
	}

	wsManager.broadcast <- joinUserNotificationMessageBytes
}

func HandleLeaveUserResponse(username string, role string) {
	wsManager := GetManager()

	joinPayload := map[string]string{
		"username": username,
		"role":     role,
	}

	joinPayloadBytes, err := json.Marshal(joinPayload)
	if err != nil {
		logger.Errorf("Error marshalling joinPayload: %v", err)
	}

	joinUserNotificationMessage := common.Message{
		Type:    common.MessageTypeUserLeaveResponse,
		Payload: joinPayloadBytes,
	}

	joinUserNotificationMessageBytes, err := json.Marshal(joinUserNotificationMessage)
	if err != nil {
		logger.Errorf("Error marshalling joinUserNotificationMessage: %v", err)
	}

	wsManager.broadcast <- joinUserNotificationMessageBytes
}
