package sfu

import (
	"encoding/json"
	"log"
	"server/common"

	"github.com/pion/webrtc/v4"
)

func HandleSDPAnswer(username string, payload json.RawMessage) {
	logger.Trace("HandleSDPAnswer Called")
	m := GetManager()
	m.mu.RLock()
	client, ok := m.Clients[username]
	m.mu.RUnlock()

	if !ok {
		logger.Warnf("Получен Answer от неизвестного клиента: %s", username)
		return
	}

	var answer webrtc.SessionDescription
	if err := json.Unmarshal(payload, &answer); err != nil {
		logger.Errorf("Ошибка парсинга Answer от %s: %v", username, err)
		return
	}

	if err := client.PeerConnection.SetRemoteDescription(answer); err != nil {
		logger.Errorf("Ошибка установки RemoteDescription (Answer) для %s: %v", username, err)
	}
}
func HandleICECandidate(username string, payload json.RawMessage) {
	logger.Tracef("HandleICECandidate вызван для пользователя: %s", username)
	m := GetManager()
	m.mu.RLock()
	client, ok := m.Clients[username]
	m.mu.RUnlock()

	if !ok || client.PeerConnection == nil {
		logger.Warnf("Получен ICE Candidate от неизвестного/неподключенного клиента: %s", username)
		return
	}

	var candidate webrtc.ICECandidateInit
	if err := json.Unmarshal(payload, &candidate); err != nil {
		logger.Errorf("Ошибка парсинга ICE Candidate от %s: %v", username, err)
		return
	}
	if err := client.PeerConnection.AddICECandidate(candidate); err != nil {
		logger.Errorf("Ошибка добавления ICE Candidate для %s: %v", username, err)
	}
}

func HandleJoinCall(username string, wsWriter common.WebSocketWriter) {
	logger.Tracef("HandleJoinCall вызван для пользователя: %s", username)
	m := GetManager()

	client, err := m.AddClient(username, wsWriter)
	if err != nil {
		logger.Errorf("Client adding error %v ", err)
		return
	}

	err = client.WebSocket.WriteJSON(&common.Message{
		Type: common.MessageTypeJoinCallSuccess,
	})
	if err != nil {
		logger.Errorf("HandleJoinCall error: %v", err)
	}
}

func HandleSDPOffer(username string, payload json.RawMessage) {
	logger.Tracef("HandleWebRTCOffer вызван для пользователя: %s", username)
	m := GetManager()
	m.mu.RLock()
	client, ok := m.Clients[username]
	m.mu.RUnlock()
	if !ok { /* ... */
		return
	}

	var offer webrtc.SessionDescription
	if err := json.Unmarshal(payload, &offer); err != nil { /* ... */
		return
	}

	if err := client.PeerConnection.SetRemoteDescription(offer); err != nil { /* ... */
		return
	}

	// Отправляем существующие треки от "старичков" этому клиенту
	m.sendExistingTracksToClient(client)

	answer, err := client.PeerConnection.CreateAnswer(nil)
	if err != nil { /* ... */
		return
	}

	gatherComplete := webrtc.GatheringCompletePromise(client.PeerConnection)
	if err := client.PeerConnection.SetLocalDescription(answer); err != nil { /* ... */
		return
	}
	<-gatherComplete

	// Отправляем Answer клиенту
	payloadBytes, _ := json.Marshal(client.PeerConnection.LocalDescription())
	client.WebSocket.WriteJSON(&common.Message{
		Type:    common.MessageTypeSdpAnswer,
		Payload: payloadBytes,
	})
}

func (manager *Manager) setupNegotiationHandler(client *Client) {
	client.PeerConnection.OnNegotiationNeeded(func() {
		logger.Infof(
			"Negotiation needed for %s. Current signaling state: %s",
			client.Username,
			client.PeerConnection.SignalingState(),
		)

		if client.PeerConnection.SignalingState() != webrtc.SignalingStateStable {
			logger.Warnf("Ignoring renegotiation offer from %s (state=%s)",
				client.Username, client.PeerConnection.SignalingState())
			return
		}
		log.Print("Negotiation triggered")

		client.mu.Lock()
		defer client.mu.Unlock()

		offer, err := client.PeerConnection.CreateOffer(nil)
		if err != nil {
			logger.Errorf("Failed to create offer for %s: %v", client.Username, err)
			return
		}

		if err := client.PeerConnection.SetLocalDescription(offer); err != nil {
			logger.Errorf("Failed to set local description for %s: %v", client.Username, err)
			return
		}

		logger.Tracef("Negotiation offer for %s", client.Username)

		offerPayload, err := json.Marshal(offer)
		if err != nil {
			logger.Errorf("Failed to marshal offer for %s: %v", client.Username, err)
		}

		if err := client.WebSocket.WriteJSON(&common.SignalingMessage{
			Type:    common.MessageTypeSdpOffer,
			Payload: offerPayload,
		}); err != nil {
			logger.Errorf("Failed to send offer to %s: %v", client.Username, err)
		}
	})
}

func (m *Manager) sendExistingTracksToClient(newClient *Client) {
	m.mu.RLock()

	for _, track := range m.TrackLocals {
		if _, err := newClient.PeerConnection.AddTrack(track); err != nil {
			logger.Errorf("Не удалось добавить существующий трек: %v", err)
		}
	}
	m.mu.RUnlock()
}

func GetSFUClients(wsWriter common.WebSocketWriter) {
	sfuManager := GetManager()

	sfuManager.mu.RLock()
	defer sfuManager.mu.RUnlock()

	activeClientsInfo := make([]common.ActiveClients, 0, len(sfuManager.Clients))

	for _, client := range sfuManager.Clients {
		activeClientsInfo = append(activeClientsInfo, common.ActiveClients{
			Username: client.Username,
		})
	}

	activeClientsInfoBytes, err := json.Marshal(activeClientsInfo)
	if err != nil {
		logger.Errorf("Failed to marshal active clients: %v", err)
		return
	}

	clientsToSend := common.Message{
		Type:    common.MessageTypeActiveClientsSFUResponse,
		Payload: activeClientsInfoBytes,
	}

	err = wsWriter.WriteJSON(clientsToSend)
	if err != nil {
		logger.Errorf("Failed to send active clients: %v", err)
	}

}
