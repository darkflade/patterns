package main

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
)

// апгрейдер
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// список клиентов
var (
	clients   = make(map[*websocket.Conn]bool)
	broadcast = make(chan string)
	mu        sync.Mutex
)

// обработка соединения
func handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}
	defer func() {
		mu.Lock()
		delete(clients, conn)
		mu.Unlock()
		conn.Close()
	}()

	mu.Lock()
	clients[conn] = true
	mu.Unlock()

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			log.Println("Read error:", err)
			break
		}
		broadcast <- string(msg)
	}
}

// слушаем канал и шлём всем
func handleMessages() {
	for {
		msg := <-broadcast
		mu.Lock()
		for client := range clients {
			err := client.WriteMessage(websocket.TextMessage, []byte(msg))
			if err != nil {
				log.Println("Write error:", err)
				client.Close()
				delete(clients, client)
			}
		}
		mu.Unlock()
	}
}

// вывод локальных IP для удобства
func printLocalIPs(port string) {
	ifaces, err := net.Interfaces()
	if err != nil {
		log.Println("Ошибка получения интерфейсов:", err)
		return
	}
	fmt.Println("Сервер слушает на порту", port, "по адресам:")
	for _, iface := range ifaces {
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}
			if ip == nil || ip.IsLoopback() {
				continue
			}
			if ipv4 := ip.To4(); ipv4 != nil {
				fmt.Printf("  ws://%s:%s/ws\n", ipv4.String(), port)
			}
		}
	}
}

func main() {
	http.HandleFunc("/ws", handleWS)
	port := "8080"

	go handleMessages()

	printLocalIPs(port)

	addr := "0.0.0.0:" + port
	log.Fatal(http.ListenAndServe(addr, nil))
}
