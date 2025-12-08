package database

import (
	"database/sql"

	_ "github.com/mattn/go-sqlite3"
)

type Message struct {
	Sender  string `json:"sender"`
	Role    string `json:"role"`
	Type    string `json:"type"`
	Content string `json:"content"`
}

// InsertMessage - сохраняет новое сообщение в БД
func InsertMessage(db *sql.DB, sender, role, message_type, content string) error {
	_, err := db.Exec("INSERT INTO messages (sender, role, type, content) VALUES (?, ?, ?, ?)", sender, role, message_type, content)
	return err
}

// GetLastMessages - получает последние N сообщений из БД
func GetLastMessages(db *sql.DB, limit int) ([]Message, error) {
	rows, err := db.Query("SELECT sender, role, type, content timestamp FROM messages ORDER BY timestamp DESC LIMIT ?", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []Message
	for rows.Next() {
		var msg Message
		if err := rows.Scan(&msg.Sender, &msg.Role, &msg.Type, &msg.Content); err != nil {
			return nil, err
		}
		messages = append(messages, msg)
	}
	return messages, nil
}
