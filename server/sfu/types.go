package sfu

import (
	common "server/common"
	"sync"

	"github.com/pion/webrtc/v4"
)

type Manager struct {
	Clients map[string]*Client
	mu      sync.RWMutex
}

type Client struct {
	Username       string
	PeerConnection *webrtc.PeerConnection
	WebSocket      common.WebSocketWriter
	Track          *webrtc.TrackLocalStaticRTP
	mu             sync.RWMutex
}
