package ws

import "log"

func (c *Client) GetUsername() string {
	return c.Username
}

func (c *Client) GetRole() string {
	return c.Role
}

func (c *Client) Send(message []byte) {
	select {
	case c.send <- message:
	default:
		log.Printf("Channel for message sending is overflow. Client %s ignored.", c.Username)
	}
}
