package ws

import (
	"encoding/json"
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
			go HandleJoinUserResponse(client.Username, client.Role)

		case client := <-manager.unregister:
			if _, ok := manager.clients[client]; ok {
				delete(manager.clients, client)
				close(client.send)
				go HandleLeaveUserResponse(client.Username, client.Role)
			}

		case message := <-manager.broadcast:
			for client := range manager.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(manager.clients, client)
				}
			}
		case event := <-sfu.EventsChannel:
			switch event.Type {
			case common.MessageTypeUserJoinSFU:
				go HandleSFUEventResponse(event.InitiatorUsername, event.Type)
			case common.MessageTypeUserLeaveSFU:
				go HandleSFUEventResponse(event.InitiatorUsername, event.Type)
			default:
				logger.Warnf("Unknown sfu event type %d", event.Type)
			}
		}

	}
}

func (c *Client) readPump() {
	defer func() {
		c.manager.unregister <- c
		sfu.GetManager().RemoveClient(c.Username)
		err := c.conn.Close()
		if err != nil {
			logger.Errorf("Close connection failed: %v", err)
		}
	}()

	for {
		_, messagePayload, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				logger.Errorf("Unexpected ws close for %s", c.Username)
			} else {
				logger.Infof("WS was closed for %s", c.Username)
			}
			break
		}

		var message common.Message
		err = json.Unmarshal(messagePayload, &message)
		if err != nil {
			logger.Errorf("Error unmarshalling message: %s\n", err)
			continue
		}

		logger.Tracef("Received message: %s\n", messagePayload)

		switch message.Type {
		case common.MessageTypeChat:
			HandleChat(c, message.Payload)
		case common.MessageTypeJoinCall:
			sfu.HandleJoinCall(c)
		case common.MessageTypeIceCandidate:
			sfu.HandleICECandidate(c.Username, message.Payload)
		case common.MessageTypeSdpAnswer:
			sfu.HandleSDPAnswer(c.Username, message.Payload)
		case common.MessageTypeSdpOffer:
			sfu.HandleSDPOffer(c, message.Payload)
		case common.MessageTypeActiveClientsWS:
			GetWSClients(c)
		case common.MessageTypeActiveClientsSFU:
			sfu.GetSFUClients(c)
		case common.MessageTypePromoteUser:
			HandlePromoteUser(c, message.Payload)
		default:
			logger.Errorf("Unknown message type: %s\n Content %v", message.Type, messagePayload)
		}

	}
}

func (c *Client) writePump() {
	defer func() {
		err := c.conn.Close()
		if err != nil {
			logger.Errorf("Close connection failed: %v", err)
		}
	}()

	for {
		message, ok := <-c.send
		if !ok {
			err := c.conn.WriteMessage(websocket.CloseMessage, []byte{})
			if err != nil {

				logger.Errorf("Write close message error: %v", err)
			}
			logger.Error("Special write pump error")
			return
		}

		err := c.conn.WriteMessage(websocket.TextMessage, message)
		if err != nil {
			logger.Errorf("Write message error: %v", err)
			return
		}
	}
}
