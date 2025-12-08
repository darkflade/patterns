package files

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/google/uuid"
)

func HandleFileUpload(w http.ResponseWriter, r *http.Request) {
	r.ParseMultipartForm(10 << 20)

	file, handler, err := r.FormFile("myFile")
	if err != nil {
		http.Error(w, "Error Retrieving the File", http.StatusBadRequest)
		return
	}
	defer file.Close()

	if err := os.MkdirAll("./uploads", os.ModePerm); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	ext := filepath.Ext(handler.Filename)
	newFileName := uuid.New().String() + ext

	dst, err := os.Create("./uploads/" + newFileName)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	filePath := "/files/" + newFileName
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"url": filePath})
}
