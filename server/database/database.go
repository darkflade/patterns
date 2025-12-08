package database

import (
	"database/sql"
	"errors"
	"log"
	"sync"

	_ "github.com/mattn/go-sqlite3"
)

var (
	db   *sql.DB
	once sync.Once
)

// InitDB initialize database structure and add if db doesn't exist
func InitDB(dataSourceName string) (*sql.DB, error) {
	var err error
	once.Do(func() {
		db, err = sql.Open("sqlite3", dataSourceName)
		if err != nil {
			return
		}

		if err = db.Ping(); err != nil {
			return
		}

		createTableSQL := `CREATE TABLE IF NOT EXISTS users (
			"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,		
			"username" TEXT NOT NULL UNIQUE,
			"role" TEXT NOT NULL,
			"password" TEXT NOT NULL
		  );`

		_, err = db.Exec(createTableSQL)
		if err != nil {
			logger.Errorf("Failed to create table users: %v", err)
			return
		}

		addUser := `INSERT INTO users (username,role,password) VALUES (?,?,?);`

		db.Exec(addUser, "admin", "admin", "admin")
		db.Exec(addUser, "moderator", "moderator", "moderator")
		db.Exec(addUser, "peasant", "peasant", "peasant")
		logger.Info("Database successfully initialized")

		createMessagesTableSQL := `CREATE TABLE IF NOT EXISTS messages (
			"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			"sender" TEXT NOT NULL,
			"role" TEXT NOT NULL,
			"type" TEXT NOT NULL DEFAULT 'text',
			"content" TEXT NOT NULL,
			"timestamp" DATETIME DEFAULT CURRENT_TIMESTAMP
		);`

		_, err = db.Exec(createMessagesTableSQL)
		if err != nil {
			logger.Errorf("Failed to create table messages: %v", err)
			return
		}
	})

	if err != nil {
		return nil, err
	}
	return db, nil
}

// GetDB return single copy of DB connection
func GetDB() *sql.DB {
	if db == nil {
		log.Fatal("Database doesn't initialized. Call InitDB")
	}
	return db
}

func CreateUser(db *sql.DB, username string, password string) (string, error) {
	var role string
	var passwordDB string

	err := db.QueryRow("SELECT role, password FROM users WHERE username = ?", username).Scan(&role, &passwordDB)
	if err != nil {
		if err == sql.ErrNoRows {
			role = "peasant"
			_, insertErr := db.Exec("INSERT INTO users (username, role, password) VALUES (?, ?, ?)", username, role, password)
			if insertErr != nil {
				logger.Errorf("Не удалось создать нового пользователя %s: %v", username, insertErr)
				return "", insertErr
			}
		} else {
			logger.Errorf("Ошибка получения роли для %s: %v", username, err)
			return "", err
		}
	}

	if password != passwordDB {
		return "", errors.New("incorrect password")
	}

	return role, nil
}

func UpdateUser(db *sql.DB, clientUsername string, clientRole string) {
	_, err := db.Exec("UPDATE users SET role = ? WHERE username = ?", clientRole, clientUsername)
	if err != nil {
		logger.Errorf("Произошла ошибка %v", err)
	}
}
