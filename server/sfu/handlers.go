package sfu

import (
	"server/common"

	"github.com/pion/webrtc/v4"
)

func HandleSDPOffer(username string, wsWriter common.WebSocketWriter, payload interface{}) {
	m := GetManager()

	var offer webrtc.SessionDescription
	offer = payload.(webrtc.SessionDescription)

	client, err := m.AddClient(username, wsWriter)

	if err := m.AddPeerConnectionAndHandlers(client); err != nil {
		return
	}

	if err := client.PeerConnection.SetRemoteDescription(offer); err != nil {
		sfuLogger.Errorf("Ошибка установки RemoteDescription для %s: %v", username, err)
		return
	}

	m.sendExistingTracksToClient(client)

	answer, err := client.PeerConnection.CreateAnswer(nil)
	if err != nil {
		sfuLogger.Errorf("Ошибка создания Answer для %s: %v", username, err)
		return
	}

	if err := client.PeerConnection.SetLocalDescription(answer); err != nil {
		sfuLogger.Errorf("Ошибка установки LocalDescription для %s: %v", username, err)
		return
	}

	err = client.WebSocket.WriteJSON(&common.Message{
		Type:    common.MessageTypeSdpAnswer,
		Payload: answer,
	})
	if err != nil {
		sfuLogger.Errorf("Ошибка отправки Answer клиенту %s: %v", username, err)
	}
}

func HandleSDPAnswer(username string, payload interface{}) {
	m := GetManager()
	m.mu.RLock()
	client, ok := m.Clients[username]
	m.mu.RUnlock()

	if !ok {
		sfuLogger.Warnf("Получен Answer от неизвестного клиента: %s", username)
		return
	}

	var answer webrtc.SessionDescription
	answer = payload.(webrtc.SessionDescription)

	if err := client.PeerConnection.SetRemoteDescription(answer); err != nil {
		sfuLogger.Errorf("Ошибка установки RemoteDescription (Answer) для %s: %v", username, err)
	}
}

func HandleICECandidate(username string, payload interface{}) {
	m := GetManager()
	m.mu.RLock()
	client, ok := m.Clients[username]
	m.mu.RUnlock()

	if !ok || client.PeerConnection == nil {
		sfuLogger.Warnf("Получен ICE Candidate от неизвестного/неподключенного клиента: %s", username)
		return
	}

	var candidate webrtc.ICECandidateInit
	candidate = payload.(webrtc.ICECandidateInit)

	if err := client.PeerConnection.AddICECandidate(candidate); err != nil {
		sfuLogger.Errorf("Ошибка добавления ICE Candidate для %s: %v", username, err)
	}
}

func (m *Manager) sendExistingTracksToClient(newClient *Client) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, otherClient := range m.Clients {
		if otherClient.Username == newClient.Username || otherClient.Track == nil {
			continue
		}
		sfuLogger.Infof("Отправляем существующий трек от '%s' новому клиенту '%s'", otherClient.Username, newClient.Username)
		if _, err := newClient.PeerConnection.AddTrack(otherClient.Track); err != nil {
			sfuLogger.Errorf("Не удалось добавить существующий трек: %v", err)
		}
	}
}
