package common

import "encoding/json"

const (
	MessageTypeChat                     = "chat_message"
	MessageTypeActiveClientsWS          = "active_clients_ws"
	MessageTypeActiveClientsSFU         = "active_clients_sfu"
	MessageTypeActiveClientsWSResponse  = "active_clients_ws_response"
	MessageTypeActiveClientsSFUResponse = "active_clients_sfu_response"
	MessageTypePromoteUser              = "promote_user"
	MessageTypePromoteUserResponse      = "promote_user_response"

	// System Messages
	MessageTypeSystem       = "system_message"
	MessageTypeSystemError  = "system_error_message"
	MessageTypeUserJoinWS   = "user_joined_ws"
	MessageTypeUserLeaveWS  = "user_left_ws"
	MessageTypeUserJoinSFU  = "user_joined_sfu"
	MessageTypeUserLeaveSFU = "user_left_sfu"

	// webrtc guys
	// Custom
	MessageTypeJoinCall        = "join_call"
	MessageTypeJoinCallSuccess = "join_call_success"
	// Default
	MessageTypeSdpOffer     = "sdp_offer"
	MessageTypeSdpAnswer    = "sdp_answer"
	MessageTypeIceCandidate = "ice_candidate"
)

type MessageSender interface {
	Send(message []byte)
}

type Message struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload"`
}

type ClientChatPayload struct {
	Text string `json:"text"`
}

type ServerChatPayload struct {
	Sender string `json:"sender"`
	Role   string `json:"role"`
	Text   string `json:"text"`
}
type PromoteUserPayload struct {
	Username string `json:"username"`
	NewRole  string `json:"new_role"`
}

type SdpPayload struct {
	SDP string `json:"sdp"`
}

type IceCandidatePayload struct {
	Candidate map[string]interface{} `json:"candidate"`
}

type SignalingMessage struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload"`
}

type ActiveClients struct {
	Username string `json:"username"`
	Role     string `json:"role"`
}
