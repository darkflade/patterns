package common

type ClientContext interface {
	GetUsername() string
	GetRole() string
	Send(message []byte)
}
