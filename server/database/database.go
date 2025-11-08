package database

import (
	"database/sql"
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
			"role" TEXT NOT NULL
		  );`

		_, err = db.Exec(createTableSQL)
		if err != nil {
			logger.Errorf("Failed to create table users: %v", err)
			return
		}

		addUser := `INSERT INTO users (username,role) VALUES (?,?);`

		db.Exec(addUser, "admin", "admin")
		db.Exec(addUser, "moderator", "moderator")
		db.Exec(addUser, "peasant", "peasant")
		logger.Info("Database successfully initialized")
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

func CreateUser(db *sql.DB, username string) (string, error) {
	var role string

	err := db.QueryRow("SELECT role FROM users WHERE username = ?", username).Scan(&role)
	if err != nil {
		if err == sql.ErrNoRows {
			role = "peasant"
			_, insertErr := db.Exec("INSERT INTO users (username, role) VALUES (?, ?)", username, role)
			if insertErr != nil {
				logger.Errorf("Не удалось создать нового пользователя %s: %v", username, insertErr)
				return "", insertErr
			}
		} else {
			log.Printf("Ошибка получения роли для %s: %v", username, err)
			return "", err
		}
	}
	return role, nil
}
