package database

import (
	cl "server/color-logger"

	"github.com/pion/logging"
)

var logger logging.LeveledLogger

func init() {
	logger = cl.Factory.NewLogger("database")
}
