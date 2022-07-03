package server

import (
	"fmt"
	"net/http"
	"text/template"
)

// HandlerRoot ...
func (s *APIServer) HandlerRoot() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {

		templ, err := template.ParseFiles("templates/index.html")
		if err != nil {
			s.logger.WithField("message_id", "0003").Error("template.ParseFiles", err)
			return
		}
		index := "index"
		templ.Execute(w, index)
	}
}

// HandlerProbeReadness ...
func (s *APIServer) HandlerProbeReadness() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "Ready")
	}
}

// HandlerProbeLivnes ...
func (s *APIServer) HandlerProbeLivnes() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "Alive")
	}
}
