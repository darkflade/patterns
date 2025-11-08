package sfu

import (
	"server/common"
	"sync"

	"github.com/pion/webrtc/v4"
)

type Manager struct {
	Clients     map[string]*Client
	TrackLocals map[string]*webrtc.TrackLocalStaticRTP
	mu          sync.RWMutex
}

type Client struct {
	Username       string
	PeerConnection *webrtc.PeerConnection
	WebSocket      common.WebSocketWriter
	mu             sync.RWMutex
}
