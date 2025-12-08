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
	Context        common.ClientContext
	TrackIDs       []string
	mu             sync.RWMutex
}

type Event struct {
	InitiatorUsername string
	Type              string
}
