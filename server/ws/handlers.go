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
	password := r.URL.Query().Get("password")

	logger.Tracef("%s try to connect", username)

	if username == "" {
		logger.Warn("No username provided")
		return
	}

	if password == "" {
		logger.Warn("No pass provided")
		return
	}

	db := database.GetDB()

	role, err := database.CreateUser(db, username, password)
	if err != nil {
		http.Error(w, "Authentication failed", http.StatusUnauthorized)
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

func HandleGetMessages(client *Client, payload json.RawMessage) {
	logger.Tracef("Клиент %s запросил историю сообщений", client.Username)

	var requestPayload common.GetMessagesPayload
	requestPayload.Limit = 50

	if payload != nil {
		if err := json.Unmarshal(payload, &requestPayload); err != nil {
			logger.Warnf("Не удалось распарсить payload для get_messages_request: %v. Используем лимит по умолчанию.", err)
		}
	}

	if requestPayload.Limit <= 0 || requestPayload.Limit > 200 {
		logger.Warnf("Клиент %s запросил некорректный лимит %d. Устанавливаем лимит 50.", client.Username, requestPayload.Limit)
		requestPayload.Limit = 50
	}

	db := database.GetDB()
	messages, err := database.GetLastMessages(db, requestPayload.Limit)
	if err != nil {
		logger.Errorf("Не удалось получить сообщения из БД: %v", err)
		sendSystemError(client, "Не удалось загрузить историю сообщений.")
		return
	}

	payloadBytes, err := json.Marshal(messages)
	if err != nil {
		logger.Errorf("Не удалось упаковать payload с сообщениями: %v", err)
		return
	}

	responseMsg := common.Message{
		Type:    common.MessageTypeGetMessagesResponse,
		Payload: payloadBytes,
	}

	responseBytes, err := json.Marshal(responseMsg)
	if err != nil {
		logger.Errorf("Не удалось упаковать финальное сообщение с историей: %v", err)
		return
	}

	client.send <- responseBytes

	logger.Tracef("Отправлено %d сообщений из истории клиенту %s", len(messages), client.Username)
}

func HandleChat(client *Client, payload json.RawMessage) {
	var clientPayload common.ClientChatPayload
	err := json.Unmarshal(payload, &clientPayload)
	if err != nil {
		logger.Errorf("Error unmarshalling payload: %v", err)
		return
	}

	serverPayload := common.ServerChatPayload{
		Sender:  client.Username,
		Role:    client.Role,
		Type:    clientPayload.Type,
		Content: clientPayload.Content,
	}

	serverPayloadBytes, err := json.Marshal(serverPayload)
	if err != nil {
		logger.Errorf("Error marshalling serverPayload: %v", err)
		return
	}

	go func() {
		db := database.GetDB()
		if err := database.InsertMessage(db, serverPayload.Sender, serverPayload.Role, serverPayload.Type, serverPayload.Content); err != nil {
			logger.Errorf("Не удалось сохранить сообщение в БД: %v", err)
		}
	}()

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

func GetWSClients(context common.ClientContext) {
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
		logger.Errorf("Error marshalling activeClientsInfo: %v", err)
	}

	context.Send(clientsToSendBytes)
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

	if promotePayload.NewRole != "admin" && promotePayload.NewRole != "moderator" && promotePayload.NewRole != "peasant" {
		sendSystemError(client, "Можно назначить только роль 'admin' 'moderator' или 'peasant'.")
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

	go sendUpdatedUserToAll(promotePayload.Username, promotePayload.NewRole)
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

func sendUpdatedUserToAll(updatedClientUsername string, updatedClientRole string) {
	logger.Debugf("Try send promoting %s :: %s", updatedClientUsername, updatedClientRole)
	manager := GetManager()

	manager.mu.RLock()
	defer manager.mu.RUnlock()

	updatedClientPayload := common.PromoteUserPayload{
		Username: updatedClientUsername,
		NewRole:  updatedClientRole,
	}

	updatedClientPayloadBytes, err := json.Marshal(updatedClientPayload)
	if err != nil {
		logger.Errorf("Error marshalling activeClientsInfo: %v", err)
		return
	}

	clientToSend := common.Message{
		Type:    common.MessageTypePromoteUserResponse,
		Payload: updatedClientPayloadBytes,
	}

	clientToSendBytes, err := json.Marshal(clientToSend)
	if err != nil {
		logger.Errorf("Error marshalling clientToSend: %v", err)
		return
	}

	manager.broadcast <- clientToSendBytes
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
		Type:    common.MessageTypeUserJoinWS,
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
		Type:    common.MessageTypeUserLeaveWS,
		Payload: joinPayloadBytes,
	}

	joinUserNotificationMessageBytes, err := json.Marshal(joinUserNotificationMessage)
	if err != nil {
		logger.Errorf("Error marshalling joinUserNotificationMessage: %v", err)
	}

	wsManager.broadcast <- joinUserNotificationMessageBytes
}

func HandleSFUEventResponse(username string, eventType string) {
	wsManager := GetManager()

	joinPayload := map[string]string{
		"username": username,
	}

	joinPayloadBytes, err := json.Marshal(joinPayload)
	if err != nil {
		logger.Errorf("Error marshalling joinPayload: %v", err)
	}

	joinUserNotificationMessage := common.Message{
		Type:    eventType,
		Payload: joinPayloadBytes,
	}

	joinUserNotificationMessageBytes, err := json.Marshal(joinUserNotificationMessage)
	if err != nil {
		logger.Errorf("Error marshalling joinUserNotificationMessage: %v", err)
	}

	wsManager.broadcast <- joinUserNotificationMessageBytes
}
