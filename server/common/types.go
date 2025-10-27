package common

const (
	MessageTypeChat         = "chat_message"
	MessageTypeSdpOffer     = "sdp_offer"
	MessageTypeSdpAnswer    = "sdp_answer"
	MessageTypeIceCandidate = "ice_candidate"
)

type Message struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload"`
}

type ChatPayload struct {
	Sender string `json:"sender"`
	Role   string `json:"role"`
	Text   string `json:"text"`
}

type SdpPayload struct {
	SDP string `json:"sdp"`
}

type IceCandidatePayload struct {
	Candidate map[string]interface{} `json:"candidate"`
}

type WebSocketWriter interface {
	WriteJSON(v interface{}) error
}

type SignalingMessage struct {
	Type   string      `json:"type"`
	RoomID string      `json:"room_id"`
	Data   interface{} `json:"data"`
}
