package server

import "os"

// Config содержит конфигурационные параметры
type Config struct {
	BindAddr     string
	LogLevel     string
	Context      string
	Probes       string
	ProbesInLogs string
}

// NewConfig получает конфигурационные параметры из среды окружения.
// если переменной среды окружения нет, подставляет значения по умолчанию.
func NewConfig() *Config {

	return &Config{
		BindAddr:     getEnv("BIND_ADDR", "127.0.0.1:8080"),
		LogLevel:     getEnv("DEFAULT_LOG_LEVEL", "info"),
		Context:      getEnv("CONTEXT", ""),
		Probes:       getEnv("PROBES", "health"),
		ProbesInLogs: getEnv("PROBES_IN_LOGS", "false"),
	}
}

// Simple helper function to read an environment or return a default value
func getEnv(key string, defaultVal string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}

	return defaultVal
}
