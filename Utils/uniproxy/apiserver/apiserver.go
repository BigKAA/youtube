package apiserver

import (
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
)

func (c Config) Start() {
	paths := c.Paths.Paths
	for i := 0; i < len(paths); i++ {
		c.addContext(paths[i])
	}
	c.Router.Run(c.BindAddr)
}

func (conf Config) addContext(path Path) {
	conf.Router.GET(path.Path, func(c *gin.Context) {
		message := make(map[string]interface{})
		message["path"] = path.Path
		message["proxyPath"] = path.ProxyPath
		message["comment"] = path.Comment
		if conf.PodName != "" {
			message["podName"] = conf.PodName
		}
		if conf.Namespace != "" {
			message["namespace"] = conf.Namespace
		}
		if path.ProxyPath != "" {
			resp, err := http.Get(path.ProxyPath)
			if err != nil {
				message["returnMessage"] = err
			} else {
				body, err := io.ReadAll(resp.Body)
				if err != nil {
					message["returnMessage"] = err
				} else {
					message["returnMessage"] = string(body)
				}
			}
		}
		c.JSON(http.StatusOK, message)
	})
}
