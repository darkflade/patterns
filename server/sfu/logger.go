package sfu

import "server/logger"

var (
	loggerFactory = &logger.ColorLoggerFactory{}
	sfuLogger     = loggerFactory.NewLogger("sfu")
)
