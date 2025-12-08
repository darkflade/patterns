package sfu

import (
	"encoding/json"
	"log"
	"server/common"
	"sync"

	"github.com/pion/rtp"
	"github.com/pion/webrtc/v4"
)

var (
	manager       *Manager
	once          sync.Once
	EventsChannel = make(chan Event, 10)
)

func GetManager() *Manager {
	once.Do(func() {
		manager = &Manager{
			Clients:     make(map[string]*Client),
			TrackLocals: make(map[string]*webrtc.TrackLocalStaticRTP),
			mu:          sync.RWMutex{},
		}
	})
	return manager
}

func (m *Manager) AddClient(context common.ClientContext) (*Client, error) {
	peerConnection, err := webrtc.NewPeerConnection(webrtc.Configuration{})
	if err != nil {
		logger.Errorf(err.Error())
		return nil, err
	}
	_, err = peerConnection.AddTransceiverFromKind(
		webrtc.RTPCodecTypeAudio,
		webrtc.RTPTransceiverInit{
			Direction: webrtc.RTPTransceiverDirectionRecvonly,
		},
	)
	if err != nil {
		logger.Errorf("AddTransceiverFromKind audio failed: %v", err)
	}

	newClient := &Client{
		Username:       context.GetUsername(),
		PeerConnection: peerConnection,
		Context:        context,
		mu:             sync.RWMutex{},
	}

	m.mu.Lock()
	m.Clients[newClient.Username] = newClient
	m.mu.Unlock()

	logger.Infof("Joined %s", newClient.Username)
	EventsChannel <- Event{InitiatorUsername: newClient.Username, Type: common.MessageTypeUserJoinSFU}

	m.setupPeerConnectionHandlers(newClient)

	return newClient, nil
}

func (m *Manager) RemoveClient(username string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	client, ok := m.Clients[username]
	if !ok {
		return
	}

	if len(client.TrackIDs) > 0 {
		logger.Infof("Удаляем %d треков от клиента %s", len(client.TrackIDs), username)
		for _, trackID := range client.TrackIDs {
			delete(m.TrackLocals, trackID)
		}
	}

	client.PeerConnection.Close()
	delete(m.Clients, username)

	EventsChannel <- Event{InitiatorUsername: username, Type: common.MessageTypeUserLeaveSFU}
	logger.Infof("Клиент '%s' удален из SFU.", username)

}

func (manager *Manager) setupPeerConnectionHandlers(client *Client) {
	manager.setupNegotiationHandler(client)

	client.PeerConnection.OnICECandidate(func(candidate *webrtc.ICECandidate) {
		if candidate == nil {
			return
		}

		candidateBytes, err := json.Marshal(candidate.ToJSON())
		if err != nil {
			logger.Errorf(err.Error())
		}

		candidateMessageBytes, err := json.Marshal(common.SignalingMessage{
			Type:    common.MessageTypeIceCandidate,
			Payload: candidateBytes,
		})

		client.Context.Send(candidateMessageBytes)
	})

	client.PeerConnection.OnConnectionStateChange(func(state webrtc.PeerConnectionState) {
		logger.Infof("Peer connection state changed for user %s: %s", client.Username, state)

		switch state {
		case webrtc.PeerConnectionStateFailed:
			log.Print("Failed to connect to Peer CLose")
			logger.Error("Failed to connect to Peer CLose")
			client.PeerConnection.Close()
		case webrtc.PeerConnectionStateClosed:
			logger.Info("Peer connection closed")
			manager.RemoveClient(client.Username)
		}
	})

	client.PeerConnection.OnTrack(func(remoteTrack *webrtc.TrackRemote, receiver *webrtc.RTPReceiver) {
		logger.Infof("Получен track от '%s'! Тип: %s", client.Username, remoteTrack.Kind())

		localTrack, newTrackErr := webrtc.NewTrackLocalStaticRTP(remoteTrack.Codec().RTPCodecCapability, remoteTrack.ID(), remoteTrack.StreamID())
		if newTrackErr != nil {
			logger.Errorf("Не удалось создать локальный трек: %v", newTrackErr)
		}

		client.mu.Lock()
		client.TrackIDs = append(client.TrackIDs, remoteTrack.ID())
		client.mu.Unlock()

		manager.mu.Lock()
		manager.TrackLocals[remoteTrack.ID()] = localTrack
		manager.mu.Unlock()

		go manager.forwardTrack(remoteTrack, localTrack)

		manager.addTrackToOtherClients(client.Username, localTrack)

	})

}

func (manager *Manager) forwardTrack(remoteTrack *webrtc.TrackRemote, localTrack *webrtc.TrackLocalStaticRTP) {
	buf := make([]byte, 1500)
	rtpPkt := &rtp.Packet{}

	for {
		i, _, readErr := remoteTrack.Read(buf)
		if readErr != nil {
			logger.Error(readErr.Error())
			// TODO RemoveTrack
			return
		}

		if err := rtpPkt.Unmarshal(buf[:i]); err != nil {
			logger.Errorf("Unmarshal rtp failed %v", err)
			continue
		}

		rtpPkt.Extension = false
		rtpPkt.Extensions = nil

		if writeErr := localTrack.WriteRTP(rtpPkt); writeErr != nil {
			logger.Error(writeErr.Error())
			return
		}
	}
}

func (manager *Manager) addTrackToOtherClients(username string, track *webrtc.TrackLocalStaticRTP) {

	logger.Info("Adding track to other clients")

	manager.mu.RLock()
	clientsToUpdate := make([]*Client, 0)
	for _, client := range manager.Clients {
		if client.Username != username {
			clientsToUpdate = append(clientsToUpdate, client)
		}
	}
	manager.mu.RUnlock()

	for _, client := range clientsToUpdate {
		logger.Debugf("Add Track to %s", client.Username)
		if _, err := client.PeerConnection.AddTrack(track); err != nil {
			logger.Errorf("Failed add track to %s: %v", client.Username, err)
		}
		sendersCount := len(client.PeerConnection.GetSenders())
		logger.Infof("✅ Трек успешно добавлен для %s. Всего треков теперь: %d", client.Username, sendersCount)
	}
}
