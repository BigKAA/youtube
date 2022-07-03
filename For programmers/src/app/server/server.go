package server

import (
	"net/http"
	"strings"

	"github.com/felixge/httpsnoop"
	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"
)

// APIServer ...
type APIServer struct {
	config *Config
	logger *logrus.Logger
	router *mux.Router
}

// New ...
func New(config *Config) *APIServer {
	return &APIServer{
		config: config,
		logger: logrus.New(),
		router: mux.NewRouter(),
	}
}

// Start ...
func (s *APIServer) Start() error {
	if err := s.ConfigLogger(); err != nil {
		return err
	}
	context := s.ConfigRouter()
	s.logger.WithField("message_id", "0001").Info("Starting server listen on: http://", s.config.BindAddr+context)

	server := &http.Server{
		Addr:    s.config.BindAddr,
		Handler: s.logRequestHandler(s.router),
		// ErrorLog: s.logger,
	}
	return server.ListenAndServe()
}

// ConfigRouter конфигурирует роутер
func (s *APIServer) ConfigRouter() string {
	//s.router.HandleFunc("/", s.HandlerRoot())
	context := s.config.Context
	if context == "" {
		context = "/"
	}
	sbr := s.router.PathPrefix(context).Subrouter()
	sbr.HandleFunc("/", s.HandlerRoot())
	sbr.HandleFunc("/"+s.config.Probes+"/readnes", s.HandlerProbeReadness())
	sbr.HandleFunc("/"+s.config.Probes+"/livnes", s.HandlerProbeLivnes())
	return context
}

// ConfigLogger конфигурация логгера
func (s *APIServer) ConfigLogger() error {
	level, err := logrus.ParseLevel(s.config.LogLevel)
	if err != nil {
		return err
	}

	s.logger.SetLevel(level)
	s.logger.SetFormatter(&logrus.JSONFormatter{})

	return nil
}

// logRequestHandler логирует запросы
func (s *APIServer) logRequestHandler(h http.Handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		m := httpsnoop.CaptureMetrics(h, w, r)
		fields := logrus.Fields{
			"method":         r.Method,
			"remote_address": r.RemoteAddr,
			"request_uri":    r.RequestURI,
			"user_agent":     r.UserAgent(),
			"status":         m.Code,
			"bytes":          m.Written,
			"duration":       m.Duration,
			"message_id":     "0002",
		}
		// Отключение вывода в логи запросов к пробам
		if !strings.Contains(r.RequestURI, s.config.Probes) {
			s.logger.WithFields(fields).Info("request")
			// Как вариант можно не использовать переменную, а выводить сообщение
			// на уровне debug
		} else if s.config.ProbesInLogs == "true" {
			s.logger.WithFields(fields).Debug("request")
		}
	}
}
