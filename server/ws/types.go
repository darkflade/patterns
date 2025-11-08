package ws

import "github.com/gorilla/websocket"

type Manager struct {
	clients    map[*Client]bool
	register   chan *Client
	unregister chan *Client
	broadcast  chan []byte
}

type Client struct {
	Username string
	Role     string
	manager  *Manager
	conn     *websocket.Conn
	send     chan []byte
}
