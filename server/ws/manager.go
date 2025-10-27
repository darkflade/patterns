package ws

import (
	"encoding/json"
	"log"
	"server/common"
	"server/sfu"
	"sync"

	"github.com/gorilla/websocket"
)

var (
	managerInstance *Manager
	once            sync.Once
)

func GetManager() *Manager {
	once.Do(func() {
		managerInstance = &Manager{
			clients:    make(map[*Client]bool),
			register:   make(chan *Client),
			unregister: make(chan *Client),
			broadcast:  make(chan []byte),
		}
	})
	return managerInstance
}

func (manager *Manager) Run() {
	for {
		select {
		case client := <-manager.register:
			manager.clients[client] = true
			// TODO Logger

		case client := <-manager.unregister:
			if _, ok := manager.clients[client]; ok {
				delete(manager.clients, client)
				close(client.send)
			}
			// TODO logger

		case message := <-manager.broadcast:
			for client := range manager.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(manager.clients, client)
				}
			}
		}
	}
}

func (c *Client) readPump() {
	defer func() {
		c.manager.unregister <- c
		c.conn.Close()
	}()

	for {
		_, messagePayload, err := c.conn.ReadMessage()
		if err != nil {
			log.Println("read:", err)
			continue
		}

		var message common.Message
		err = json.Unmarshal(messagePayload, &message)
		if err != nil {
			log.Printf("Error unmarshalling message: %s\n", err)
			continue
		}

		switch message.Type {
		case common.MessageTypeChat:
			c.manager.broadcast <- messagePayload
		case common.MessageTypeIceCandidate:
			sfu.HandleICECandidate(message.Type, message.Payload)
		case common.MessageTypeSdpAnswer:
			sfu.HandleSDPAnswer(message.Type, message.Payload)
		case common.MessageTypeSdpOffer:
			sfu.HandleSDPOffer(message.Type, c.conn, message.Payload)

		}

	}
}

func (c *Client) writePump() {
	defer func() {
		c.conn.Close()
	}()

	for {
		message, ok := <-c.send
		if !ok {
			c.conn.WriteMessage(websocket.CloseMessage, []byte{})
			return
		}

		err := c.conn.WriteMessage(websocket.TextMessage, message)
		if err != nil {
			log.Println("write:", err)
			return
		}
	}
}
