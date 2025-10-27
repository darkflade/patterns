package logger

import (
	"fmt"
	"log"

	"github.com/pion/logging"
)

type ColorLogger struct {
	scope string
}
type ColorLoggerFactory struct{}

func (f *ColorLoggerFactory) NewLogger(scope string) logging.LeveledLogger {
	return &ColorLogger{scope: scope}
}

func (l *ColorLogger) log(level string, color string, msg string) {
	log.Printf("%s[%s] [%s] %s%s", color, level, l.scope, msg, colorReset)
}

// Logger levels appearance

func (l *ColorLogger) Trace(msg string) {
	l.log("TRACE", colorGray, msg)
}
func (l *ColorLogger) Tracef(format string, args ...interface{}) {
	l.Trace(fmt.Sprintf(format, args...))
}

func (l *ColorLogger) Debug(msg string) {
	l.log("DEBUG", colorCyan, msg)
}
func (l *ColorLogger) Debugf(format string, args ...interface{}) {
	l.Debug(fmt.Sprintf(format, args...))
}

func (l *ColorLogger) Info(msg string) {
	l.log("INFO", colorBlue, msg)
}
func (l *ColorLogger) Infof(format string, args ...interface{}) {
	l.Info(fmt.Sprintf(format, args...))
}

func (l *ColorLogger) Warn(msg string) {
	l.log("WARN", colorYellow, msg)
}
func (l *ColorLogger) Warnf(format string, args ...interface{}) {
	l.Warn(fmt.Sprintf(format, args...))
}

func (l *ColorLogger) Error(msg string) {
	l.log("ERROR", colorRed, msg)
}
func (l *ColorLogger) Errorf(format string, args ...interface{}) {
	l.Error(fmt.Sprintf(format, args...))
}
