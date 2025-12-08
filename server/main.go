package main

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"server/database"
	"server/files"
	"server/ws"
)

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

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
	// WS Manager
	manager := ws.GetManager()
	go manager.Run()

	// Database init
	_, err := database.InitDB("./chat.db")
	if err != nil {
		log.Fatalf("For some reason failed init database: %v", err)
	}

	fs := withCORS(http.FileServer(http.Dir("./uploads")))
	http.Handle("/files/", withCORS(http.StripPrefix("/files/", fs)))
	http.HandleFunc("/upload", func(w http.ResponseWriter, r *http.Request) {
		withCORS(http.HandlerFunc(files.HandleFileUpload)).ServeHTTP(w, r)
	})

	// HTTP Server
	http.HandleFunc("/ws", ws.HandleWS)
	port := "8080"
	printLocalIPs(port)
	addr := "0.0.0.0:" + port
	log.Fatal(http.ListenAndServe(addr, nil))
}
