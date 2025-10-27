package sfu

import (
	"log"
	"server/common"
	"sync"

	"github.com/pion/rtp"
	"github.com/pion/webrtc/v4"
)

var (
	manager *Manager
	once    sync.Once
)

func GetManager() *Manager {
	once.Do(func() {
		manager = &Manager{
			Clients: make(map[string]*Client),
			mu:      sync.RWMutex{},
		}
	})
	return manager
}

func (m *Manager) AddPeerConnectionAndHandlers(client *Client) error {
	peerConnection, err := webrtc.NewPeerConnection(webrtc.Configuration{})
	if err != nil {
		sfuLogger.Errorf("Не удалось создать PeerConnection для %s: %v", client.Username, err)
		return err
	}
	client.PeerConnection = peerConnection

	sfuLogger.Infof("PeerConnection для '%s' создан. Настраиваем обработчики...", client.Username)
	// Используем 'm' (ресивер) вместо глобального 'manager'
	m.setupPeerConnectionHandlers(client)
	return nil
}

func (m *Manager) AddClient(username string, wsWriter common.WebSocketWriter) (*Client, error) {
	/*peerConnection, err := webrtc.NewPeerConnection(webrtc.Configuration{})
	if err != nil {
		sfuLogger.Errorf(err.Error())
		return nil, err
	}*/

	newClient := &Client{
		Username: username,
		// PeerConnection: peerConnection,
		WebSocket: wsWriter,
		mu:        sync.RWMutex{},
	}

	m.mu.Lock()
	m.Clients[username] = newClient
	m.mu.Unlock()

	sfuLogger.Infof("Joined %s", username)
	m.setupPeerConnectionHandlers(newClient)

	return newClient, nil
}

func (m *Manager) RemoveClient(username string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	client, ok := m.Clients[username]
	if ok {
		client.PeerConnection.Close()
		delete(m.Clients, username)
		sfuLogger.Infof("Клиент '%s' удален.", username)
	}
}

func (manager *Manager) setupPeerConnectionHandlers(client *Client) {
	manager.setupNegotiationHandler(client)

	client.PeerConnection.OnICECandidate(func(candidate *webrtc.ICECandidate) {
		if candidate == nil {
			return
		}

		client.WebSocket.WriteJSON(&common.SignalingMessage{
			Type: "sfu_ice_candidate",
			Data: candidate.ToJSON(),
		})
	})

	client.PeerConnection.OnConnectionStateChange(func(state webrtc.PeerConnectionState) {
		sfuLogger.Infof("Peer connection state changed for user %s: %s", client.Username, state)

		switch state {
		case webrtc.PeerConnectionStateFailed:
			log.Print("Failed to connect to Peer CLose")
			sfuLogger.Error("Failed to connect to Peer CLose")
			client.PeerConnection.Close()
		case webrtc.PeerConnectionStateClosed:
			sfuLogger.Info("Peer connection closed")
			manager.RemoveClient(client.Username)
		}
	})

	client.PeerConnection.OnTrack(func(remoteTrack *webrtc.TrackRemote, receiver *webrtc.RTPReceiver) {
		sfuLogger.Infof("Получен track от '%s'! Тип: %s", client.Username, remoteTrack.Kind())

		localTrack, newTrackErr := webrtc.NewTrackLocalStaticRTP(remoteTrack.Codec().RTPCodecCapability, remoteTrack.ID(), remoteTrack.StreamID())

		if newTrackErr != nil {
			sfuLogger.Errorf("Не удалось создать локальный трек: %v", newTrackErr)
		}

		client.mu.Lock()
		client.Track = localTrack
		client.mu.Unlock()

		manager.mu.RLock()
		defer manager.mu.RUnlock()

		go manager.forwardTrack(remoteTrack, localTrack)

		manager.addTrackToOtherClients(client.Username, localTrack)

	})

}

func (manager *Manager) setupNegotiationHandler(client *Client) {
	client.PeerConnection.OnNegotiationNeeded(func() {
		sfuLogger.Infof(
			"Negotiation needed for %s. Current signaling state: %s",
			client.Username,
			client.PeerConnection.SignalingState(),
		)

		log.Print("Negotiation triggered")

		client.mu.Lock()
		defer client.mu.Unlock()

		offer, err := client.PeerConnection.CreateOffer(nil)
		if err != nil {
			sfuLogger.Errorf("Failed to create offer for %s: %v", client.Username, err)
			return
		}

		if err := client.PeerConnection.SetLocalDescription(offer); err != nil {
			sfuLogger.Errorf("Failed to set local description for %s: %v", client.Username, err)
			return
		}

		if err := client.WebSocket.WriteJSON(&common.SignalingMessage{
			Type: "sfu_offer",
			Data: offer,
		}); err != nil {
			sfuLogger.Errorf("Failed to send offer to %s: %v", client.Username, err)
		}
	})
}

func (manager *Manager) forwardTrack(remoteTrack *webrtc.TrackRemote, localTrack *webrtc.TrackLocalStaticRTP) {
	buf := make([]byte, 1500)
	rtpPkt := &rtp.Packet{}

	for {
		i, _, readErr := remoteTrack.Read(buf)
		if readErr != nil {
			sfuLogger.Error(readErr.Error())
			// TODO RemoveTrack
			return
		}

		if err := rtpPkt.Unmarshal(buf[:i]); err != nil {
			sfuLogger.Errorf("Unmarshal rtp failed %v", err)
			continue
		}

		rtpPkt.Extension = false
		rtpPkt.Extensions = nil

		if writeErr := localTrack.WriteRTP(rtpPkt); writeErr != nil {
			sfuLogger.Error(writeErr.Error())
			return
		}
	}
}

func (manager *Manager) addTrackToOtherClients(username string, track *webrtc.TrackLocalStaticRTP) {

	manager.mu.RLock()
	clientsToUpdate := make([]*Client, 0)
	for _, client := range manager.Clients {
		if client.Username != username {
			clientsToUpdate = append(clientsToUpdate, client)
		}
	}
	manager.mu.RUnlock()

	for _, client := range clientsToUpdate {
		if _, err := client.PeerConnection.AddTrack(track); err != nil {
			sfuLogger.Errorf("Failed add track to %s: %v", client.Username, err)
		}
	}
}
