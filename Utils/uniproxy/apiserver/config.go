package apiserver

import (
	"encoding/json"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v2"
)

// Описание маршрута
type Path struct {
	Path      string `yaml:"path"`
	ProxyPath string `yaml:"proxyPath"`
	Comment   string `yaml:"comment"`
}

// Массив путей. Для удобства парсинга конфигурационного файла
type Paths struct {
	Paths []Path `yaml:"paths"`
}

// Config содержит конфигурационные параметры
type Config struct {
	Logger    *logrus.Logger
	Router    *gin.Engine
	BindAddr  string
	Paths     *Paths
	PodName   string
	Namespace string
}

// NewConfig получает конфигурационные параметры из среды окружения.
// если переменной среды окружения нет, подставляет значения по умолчанию.
func NewConfig() (*Config, error) {
	logger := logrus.New()
	if err := ConfigLogger(logger); err != nil {
		return nil, err
	}

	return &Config{
		Logger:    logger,
		Router:    initGinEngine(),
		BindAddr:  getEnv("BIND_ADDR", "0.0.0.0:8080"),
		Paths:     loadConfig(logger),
		PodName:   getEnv("POD_NAME", ""),
		Namespace: getEnv("NAMESPACE", ""),
	}, nil
}

// Simple helper function to read an environment or return a default value
func getEnv(key string, defaultVal string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}

	return defaultVal
}

// Инициализация gin
func initGinEngine() *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(jsonLoggerMiddleware())

	return router
}

// Включаем логи в gin в json формате
func jsonLoggerMiddleware() gin.HandlerFunc {
	return gin.LoggerWithFormatter(
		func(params gin.LogFormatterParams) string {
			log := make(map[string]interface{})

			log["status_code"] = params.StatusCode
			log["body_size"] = params.BodySize
			log["path"] = params.Path
			log["method"] = params.Method
			log["time"] = params.TimeStamp.Format("2006-01-02T15:04:05.0000 -0700")
			log["remote_addr"] = params.ClientIP
			log["response_time"] = params.Latency.String()

			s, _ := json.Marshal(log)
			return string(s) + "\n"
		},
	)
}

// Load config from file
func loadConfig(logger *logrus.Logger) *Paths {
	configFile := getEnv("CONFIG_FILE", "/etc/uniproxy/uniproxy.yaml")

	yamlFile, err := os.ReadFile(configFile)
	if err != nil {
		logger.Fatalf("yamlFile.Get err   #%v ", err)
	}
	p := &Paths{}
	err = yaml.Unmarshal(yamlFile, p)
	if err != nil {
		logger.Fatalf("Unmarshal: %v", err)
	}

	return p
}

// ConfigLogger конфигурация логгера
func ConfigLogger(logger *logrus.Logger) error {
	level, err := logrus.ParseLevel(getEnv("LOG_LEVEL", "info"))
	if err != nil {
		return err
	}

	logger.SetLevel(level)
	logger.SetFormatter(&logrus.JSONFormatter{})

	return nil
}
